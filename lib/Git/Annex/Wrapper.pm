package Git::Annex::Wrapper;
# ABSTRACT: class used in implementation of Git::Annex::annex
#
# Copyright (C) 2020  Sean Whitton <spwhitton@spwhitton.name>
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

=head1 DESCRIPTION

See documentation for L<Git::Annex::annex>.

=cut

use 5.028;
use strict;
use warnings;

# credits to Git::Wrapper's author for the idea of accessing
# subcommands in this way; I've just extended that idea to
# subsubcommands of git
AUTOLOAD {
    my $self = shift;
    (my $subcommand = our $AUTOLOAD) =~ s/.+:://;
    return if $subcommand eq "DESTROY";
    $subcommand =~ tr/_/-/;
    $$self->git->RUN("annex", $subcommand, @_);
}

1;
