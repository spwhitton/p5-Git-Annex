package App::annex_to_annex_dropunused;
# ABSTRACT: drop old hardlinks migrated by annex-to-annex
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

use 5.028;
use strict;
use warnings;

use autodie;
use Git::Annex;

# This script used to have a --dest option which specified the
# destination annex previously used with annex-to-annex.  Then, if the
# unused file had a hardlink count of 1, but was present in the
# destination annex, this script would drop it.
#
# That was somewhat dangerous functionality because it involves this
# script running `git annex dropunused --force` for files with a
# hardlink count of 1.  And further, it is not actually needed,
# because running annex-to-annex-reinject after
# annex-to-annex-dropunused handles such files in a way that is safer.
#
# It is still good to run this script before annex-to-annex-reinject
# to make the latter faster.

exit main() unless caller;

=func main

Implementation of annex-to-annex-dropunused(1).  Please see
documentation for that command.

=cut

sub main {
    shift if $_[0] and ref $_[0] eq ""; # in case main called as a class method
    local @ARGV = @{ $_[0] } if $_[0] and ref $_[0] ne "";

    my $annex = Git::Annex->new;

    my @to_drop;
    my @unused_files = grep { !$_->{bad} && !$_->{tmp} } @{ $annex->unused };

    foreach my $unused_file (@unused_files) {
        my $content    = $annex->abs_contentlocation($unused_file->{key});
        my $link_count = (stat $content)[3];
        my @logs
          = $annex->git->log({ no_textconv => 1 }, "-S", $unused_file->{key});

        next
          unless $logs[0]
          and $logs[0]->message =~ /migrated by annex-to-annex/;
        next unless $link_count > 1;

        push @to_drop, $unused_file->{number};
    }

    $annex->git->annex("dropunused", { force => 1 }, @to_drop);

    return 0;
}

1;
