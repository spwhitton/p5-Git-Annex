#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use Test::More;
use File::Spec::Functions qw(rel2abs);
use t::Setup;
use File::chdir;

# make sure that `make test` will always use the right version of the
# script we seek to test
my $a2a    = "annex-to-annex";
my $a2a_ri = "annex-to-annex-reinject";
$a2a = rel2abs "blib/script/annex-to-annex" if -x "blib/script/annex-to-annex";
$a2a_ri = rel2abs "blib/script/annex-to-annex-reinject"
  if -x "blib/script/annex-to-annex-reinject";

with_temp_annexes {
    my (undef, undef, $source2) = @_;

    system $a2a, qw(--commit source1/foo source2/other dest);
    {
        local $CWD = "source2";
        $source2->checkout("master~1");
        ok $source2->annex(qw(find --in=here other)) == 1,
          "other is initially present";
        $source2->checkout("master");
    }
    system $a2a_ri, qw(source2 dest);
    {
        local $CWD = "source2";
        $source2->checkout("master~1");
        ok $source2->annex(qw(find --in=here other)) == 0,
          "other is reinjected";
        $source2->checkout("master");
    }
};

done_testing;
