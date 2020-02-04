# Git::Annex
# Perl interface to git-annex repositories
#
# Copyright (C) 2019-2020  Sean Whitton <spwhitton@spwhitton.name>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

Git::Annex - Perl interface to git-annex repositories

=head1 SYNOPSIS

  my $annex = Git::Annex->new("/home/spwhitton/annex");

  # run `git annex unused` and then `git log` to get information about
  # unused git annex keys
  my $unused_files
    = $self->unused(used_refspec => "+refs/heads/master", log => 1);
  for my $unused_file (@$unused_files) {
      say "unused file " . $unused_file->{key} . ":";
      say "";
      say "  $_" for $unused_file->{log_lines};
      say "";
      say "you can drop it with: `git annex dropunused "
        . $unused_file->{number} . "`";
      say "";
  }

  # embedded Git::Wrapper instance; catch exceptions with Try::Tiny
  say for $annex->git->annex(qw(find --not --in here));
  $annex->git->annex(qw(copy -t cloud --in here --and --lackingcopies=1));

=head1 DESCRIPTION

An instance of the Git::Annex class represents a git repository in
which C<git annex init> has been run.  This module provides some
useful methods for working with such repositories from Perl.  See
L<https://git-annex.branchable.com/> for more information on
git-annex.

=cut

package Git::Annex;

use 5.028;
use strict;
use warnings;

use Cwd;
use File::chdir;
use Git::Wrapper;
use Git::Repository;
use Try::Tiny;
use File::Spec::Functions qw(catfile rel2abs);
use Storable;
use Data::Compare;
use List::Util qw(all);
use Time::HiRes qw(stat time);
use Git::Annex::BatchCommand;

use Moo;
use namespace::clean;

=head1 METHODS

=head2 toplevel

Returns the toplevel of the repository.

=cut

has toplevel => (is => 'ro');

=head2 git

Returns an instance of L<Git::Wrapper> initialised in the repository.

=cut

has git => (
    is      => 'lazy',
    default => sub { Git::Wrapper->new(shift->toplevel) });

=head2 repo

Returns an instance of L<Git::Repository> initialised in the repository.

=cut

has repo => (
    is => 'lazy',
    # we don't know (here) whether our repo is bare or not, so we
    # don't know whether to use the git_dir or work_tree arguments to
    # Git::Repository::new, so we chdir and let call without arguments
    default => sub { local $CWD = shift->toplevel; Git::Repository->new });

=head2 unused(%opts)

Runs C<git annex unused> and returns a hashref containing information
on unused files.

The information is cached inside the C<.git/annex> directory.  This
means that a user can keep running your script without repeatedly
executing expensive C<git annex> and C<git log> commands.

Optional arguments:

=over

=item log

If true, run C<git log --stat -S> on each unused file, to see what
filenames the unused data had if and when it was used data in the
annex.

Defaults to false, but if there is log data in the cache it will
always be returned.

=item from

Corresponds to the C<--from> option to C<git annex unused>.

=item used_refspec

Corresponds to the C<--used-refspec> option to C<git annex unused>.

Defaults to the C<annex.used-refspec> git config key if set, or
C<+refs/heads/*:-refs/heads/synced/*>.

=back

=cut

sub unused {
    my ($self, %opts) = @_;
    $opts{log} //= 0;
    my $used_refspec_config;
    try { ($used_refspec_config) = $self->git->config("annex.used-refspec") };
    $opts{used_refspec}
      //= ($used_refspec_config // "+refs/heads/*:-refs/heads/synced/*");

    my %unused_args;
    for (qw(from used_refspec)) {
        $unused_args{$_} = $opts{$_} if defined $opts{$_};
    }

    $self->{_unused} //= retrieve $self->_unused_cache
      if -e $self->_unused_cache;
    # see if cache needs to be invalidated, whether or not we just
    # retrieved it
    if (defined $self->{_unused}) {
        my $git_annex_unused = $self->_git_path(qw(annex unused));
        my $last_unused      = (stat $git_annex_unused)[9];
        my %branch_timestamps
          = map { split }
          $self->git->for_each_ref(
            { format => '%(refname:short) %(committerdate:unix)' },
            "refs/heads/");

        # we don't need to invalidate the cache if the git-annex
        # branch has changed, because the worst that can happen is we
        # try to drop a file which has already been dropped
        delete $branch_timestamps{'git-annex'};

        $self->_clear_unused_cache
          unless $last_unused <= $self->{_unused}{timestamp}
          and Compare(\%unused_args, $self->{_unused}{unused_args})
          and all { $_ < $last_unused } values %branch_timestamps;
    }

    # get the unused info if we couldn't load from the cache or had to
    # invalidate it
    unless (defined $self->{_unused}) {
        my ($bad, $tmp) = (0, 0);
        $self->{_unused}{unused_args} = \%unused_args;
        # make a copy of %unused_args because Git::Wrapper will remove
        # them from the hash
        for ($self->git->annex("unused", {%unused_args})) {
            if (
/Some corrupted files have been preserved by fsck, just in case/
            ) {
                ($bad, $tmp) = (1, 0);
            } elsif (
                /Some partially transferred data exists in temporary files/) {
                ($bad, $tmp) = (0, 1);
            } elsif (/^    ([0-9]+) +([^ ]+)$/) {
                push @{ $self->{_unused}{unused} },
                  { number => $1, key => $2, bad => $bad, tmp => $tmp };
            }
        }
        $self->_store_unused_cache;
    }

    # run any needed calls to git-log(1)
    if ($opts{log}) {
        my $changed = 0;
        foreach my $unused_file (@{ $self->{_unused}{unused} }) {
            next
              if defined $unused_file->{log_lines}
              or $unused_file->{bad}
              or $unused_file->{tmp};
            $changed = 1;
            # We need the RUN here to avoid special postprocessing but
            # also to get the -c option passed -- unclear how to pass
            # short options to git itself, not the 'log' subcommand,
            # with Git::Wrapper except by using RUN (passing long
            # options to git itself is easy, per Git::Wrapper docs)
            @{ $unused_file->{log_lines} } = $self->git->RUN(
                "-c",
                "diff.renameLimit=3000",
                "log",
                {
                    stat        => 1,
                    no_textconv => 1
                },
                "--color=always",
                "-S",
                $unused_file->{key});
        }
        $self->_store_unused_cache if $changed;
    }

    return $self->{_unused}{unused};
}

has _unused_cache => (
    is      => "lazy",
    default => sub { shift->_git_path(qw(annex unused_info)) });

sub _store_unused_cache {
    my $self = shift;
    $self->{_unused}{timestamp} = time;
    store $self->{_unused}, $self->_unused_cache;
}

sub _clear_unused_cache {
    my $self = shift;
    delete $self->{_unused};
    unlink $self->_unused_cache;
}

=head2 abs_contentlocation($key)

Returns an absolute path to the content for git-annex key C<$key>.

=cut

sub abs_contentlocation {
    my ($self, $key) = @_;
    my $contentlocation;
    try { ($contentlocation) = $self->git->annex("contentlocation", $key) };
    $contentlocation ? rel2abs($contentlocation, $self->toplevel) : undef;
}

=head2 batch($cmd, @args)

Instantiate a C<Git::Annex::BatchCommand> object by starting up a
git-annex C<--batch> command.

  my $batch = $annex->batch("find", "--in=here");
  say "foo/bar annexed content is present in this repo"
    if $batch->say("foo/bar");

  # kill the batch process:
  undef $batch;

=cut

sub batch { Git::Annex::BatchCommand->new(@_) }

sub _git_path {
    my ($self, @input) = @_;
    my ($path) = $self->git->rev_parse({ git_path => 1 }, catfile @input);
    rel2abs $path, $self->toplevel;
}

around BUILDARGS => sub {
    my (undef, undef, @args) = @_;

    my $toplevel = $args[0] ? rel2abs($args[0]) : getcwd;

    # if we're in a working tree, rise up to the root of the working
    # tree -- for flexibility, don't require that we're actually in a
    # git repo at all
    my $pid = fork;
    die "fork() failed: $!" unless defined $pid;
    if ($pid) {
        wait;
        if ($?) {
            chomp($toplevel = `git -C $toplevel rev-parse --show-toplevel`);
            die "git rev-parse --show-toplevel failed" if $?;
        }
    } else {
        close STDERR;
        chomp(my $output = `git -C $toplevel rev-parse --is-inside-work-tree`);
        exit ($output and $output eq "true");
    }

    return { toplevel => $toplevel };
};

1;
