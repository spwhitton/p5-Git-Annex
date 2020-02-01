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

=head1 VERSION

version 0.01

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
use File::Spec::Functions qw(catfile rel2abs);

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

sub _git_path {
    my ($self, @input) = @_;
    my ($path) = $self->git->rev_parse({ git_path => 1 }, catfile @input);
    rel2abs($path, $self->toplevel);
}

around BUILDARGS => sub {
    my (undef, undef, @args) = @_;
    { toplevel => $args[0] // getcwd };
};

1;
