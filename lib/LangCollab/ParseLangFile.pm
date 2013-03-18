package LangCollab::ParseLangFile;
use strict;
use warnings;

my $seperators = {
    '[' => ']',
    '{' => '}',
    '(' => ')',
};

sub extract_string {
    my $rec = shift;
    # $rec = { tokens => [], rest => 'sdfdff', buf => '' };
    my @parts = split qr/([\'\"\#]|qq?.)/, $rec->{rest}, 2;
    return unless scalar(@parts) == 3;
    my $start = $rec->{buf};
    $rec->{buf} = '';
    $start .= shift @parts;
    my $sep = shift @parts;
    my $rest = shift @parts;

    if ($sep eq '#') {
        # a comment. eat the rest of the line
        @parts = split qr/(\n)/, $rest, 2;
        $rec->{rest} = pop @parts;
        $rec->{buf} = $start . $sep . join('', @parts);
        return 1;
    }
    push @{ $rec->{tokens} }, [ 'TEXT', $start ];
    $rec->{rest} = $rest;

    my $endsep = $sep;
    my $bk_sep;
    if ($sep =~ /^qq?(.)$/) {
        # we have either q{ or qq{
        my $sepchar = $2;
        if (exists $seperators->{$sepchar}) {
            $endsep = $seperators->{$sepchar};
            $bk_sep = $sepchar;
        }
        else {
            $endsep = $sepchar;
        }
    }
    my $string = '';
    if ($bk_sep) {
        my $deep = 0;
        while (1) {
            my ($buf, $char);
            ($buf, $char, $rest) = split /($endsep|$bk_sep)/, $rest, 2;
            return unless defined $rest;
            $string .= $buf;
            my ($slashs) = $buf =~ m!(/*)$!;
            if (length($slashs) % 2 == 1) {
                # ah, we have spashed seperator. 
                $string .= $char;
                next;
            }
            elsif ($char eq $bk_sep) {
                # a start baracks in the middle of the string
                $deep++;
                $string .= $char;
                next;
            }
            elsif ($deep == 0) {
                # end of string
                last;
            }
            else {
                # end of barack in the middle of the string
                $deep--;
                $string .= $char;
                next;
            }
        }
    }
    else {
        while (1) {
            (my $buf, $rest) = split $endsep, $rest, 2;
            return unless defined $rest;
            $string .= $buf;
            my ($slashs) = $buf =~ m!(/*)$!;
            if (length($slashs) % 2 == 1) {
                # ah, we have spashed end seperator. 
                $string .= $endsep;
                next;
            }
            else {
                # end of string
                last;
            }
        }
    }
    $rec->{rest} = $rest;
    push @{ $rec->{tokens} }, ['STR', $string, $sep, $endsep];
    return 1;
}

sub parse {
    my ($class, $content) = @_;
    my @parts = split qr/(\%Lexicon\s*=\s*\()/sm, $content, 2;
    return unless scalar(@parts) == 3;
    my $rest = pop @parts;
    my $start = join '', @parts;
    @parts = ();
    my $rec= { tokens => [], rest => $rest, buf => $start };
    while ( extract_string( $rec ) ) {}
    my $final = '';
    $final .= $rec->{buf}  if defined $rec->{buf};
    $final .= $rec->{rest} if defined $rec->{rest};
    if (length($final) > 0) {
        push @{ $rec->{tokens} }, ['TEXT', $final];
    }
    return $rec->{tokens};
}

1;
