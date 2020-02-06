#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use Test::More;
use File::Spec::Functions qw(rel2abs);
use t::Setup;
use t::Util;
use File::chdir;
use File::Basename qw(dirname);
use File::Copy qw(copy);

plan skip_all => "device ID issues" if device_id_issues;

# make sure that `make test` will always use the right version of the
# script we seek to test
my $a2a    = "annex-to-annex";
my $a2a_du = "annex-to-annex-dropunused";
$a2a = rel2abs "blib/script/annex-to-annex" if -x "blib/script/annex-to-annex";
$a2a_du = rel2abs "blib/script/annex-to-annex-dropunused"
  if -x "blib/script/annex-to-annex-dropunused";

with_temp_annexes {
    my (undef, undef, $source2) = @_;

    system $a2a, qw(--commit source1/foo source2/other dest);

    {
        local $CWD = "source2";
        system $a2a_du;
        $source2->checkout("master~1");
        ok((lstat "other" and not stat "other"), "other was dropped");
    }
};

with_temp_annexes {
    my (undef, undef, $source2) = @_;

    system $a2a, qw(--commit source1/foo source2/other dest);

    {
        local $CWD = "source2";

        $source2->checkout("master~1");
        my ($other_key) = $source2->annex(qw(lookupkey other));
        my ($other_content) = $source2->annex("contentlocation", $other_key);
        $source2->checkout("master");

        # break the hardlink
        chmod 0755, dirname $other_content;
        copy $other_content, "$other_content.tmp";
        system "mv", "-f", "$other_content.tmp", $other_content;
        chmod 0555, dirname $other_content;

        system $a2a_du;
        $source2->checkout("master~1");
        ok((lstat "other" and stat "other"), "other was not dropped");
        # $source2->checkout("master");
        # system $a2a_du, "--dest=../dest";
        # $source2->checkout("master~1");
        # ok((lstat "other" and not stat "other"), "other was dropped");
    }
};

# with_temp_annexes {
#     my (undef, undef, $source2, $dest) = @_;

#     system $a2a, qw(--commit source1/foo source2/other dest);

#     $dest->annex(qw(drop --force other));
#     {
#         local $CWD = "source2";

#         $source2->checkout("master~1");
#         my ($other_key) = $source2->annex(qw(lookupkey other));
#         my ($other_content) = $source2->annex("contentlocation", $other_key);
#         $source2->checkout("master");

#         # break the hardlink
#         chmod 0755, dirname $other_content;
#         copy $other_content, "$other_content.tmp";
#         system "mv", "-f", "$other_content.tmp", $other_content;
#         chmod 0555, dirname $other_content;

#         system $a2a_du, "--dest=../dest";
#         $source2->checkout("master~1");
#         ok((lstat "other" and stat "other"), "other was not dropped");
#     }
# };

done_testing;
