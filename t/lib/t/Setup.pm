package t::Setup;

use 5.028;
use strict;
use warnings;
use parent 'Exporter';

use File::Slurp;
use File::Temp qw(tempdir);
use Git::Wrapper;
use File::Spec::Functions qw(catfile);

our @EXPORT = qw( with_temp_annex );

sub with_temp_annex (&) {
    my $temp = tempdir CLEANUP => 1;
    my $git = Git::Wrapper->new($temp);
    $git->init;
    $git->annex("init");
    write_file catfile($temp, "foo"), "my cool big file\n";
    $git->annex(qw(add foo));
    $git->commit({message => "add"});
    &{$_[0]}($temp);
}

1;
