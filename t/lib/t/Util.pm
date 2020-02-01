package t::Util;

use 5.028;
use strict;
use warnings;
use parent 'Exporter';
use File::Slurp;
use File::Spec::Functions qw(rel2abs);

our @EXPORT = qw( corrupt_annexed_file );

sub corrupt_annexed_file {
    my ($git, $file) = @_;

    my ($key) = $git->annex("lookupkey", $file);
    my ($loc) = $git->annex("contentlocation", $key);
    $loc = rel2abs $loc, $git->dir;

    chmod 0777, $loc;
    append_file $loc, "bazbaz\n";
}

1;
