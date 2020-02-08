#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use App::annex_review_unused;
use Test::More;
use t::Setup;
use t::Util;
use File::chdir;
use File::Spec::Functions qw(rel2abs);
use Capture::Tiny qw(capture_stdout);

with_temp_annexes {
    my (undef, $source1) = @_;
    my ($output, $exit);

    {
        local $CWD = "source1";
        (undef, undef, $exit) = run_bin "annex-review-unused";
        ok !$exit, "it exits zero when no unused files";
        sleep 1;
        $source1->rm("foo/foo2/baz");
        $source1->commit({ message => "rm" });

        ($output, undef, $exit) = run_bin qw(annex-review-unused --just-print);
        ok $exit, "it exits nonzero when unused files";
        ok 20 < @$output && @$output < 30, "it prints ~two log entries";
        like $output->[5], qr/unused file #1/, "it prints an expected line";
    }
};

done_testing;
