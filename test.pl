use strict;
use warnings;
use lib './extlib', './lib';
use Data::Dumper;
use LangCollab::ParseLangFile;

open my $fh, "< :utf8", "/Users/sfomberg/code/mt-plugin-entryfiledrop/plugins/EntryFileDrop/lib/EntryFileDrop/L10N/ja.pm"
    or die "failed to open file";
my $content = do { local $/ = <$fh> };
close $fh;

my $tokens = LangCollab::ParseLangFile->parse($content);

my %hash = map { $_->[1] } grep { $_->[0] eq 'STR' } @$tokens;

while (my ($key, $val) = each %hash) {
    print "$key => $val\n";
}
