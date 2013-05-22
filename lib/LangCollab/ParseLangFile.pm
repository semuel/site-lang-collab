package LangCollab::ParseLangFile;
use strict;
use warnings;

my $seperators = {
    '[' => ']',
    '{' => '}',
    '(' => ')',
};

sub extract_space {
    my $rec = shift;
    my ($space) = $rec->{rest} =~ m/^((?:,|\s|=>)*)/s;
    if (length($space) > 0) {
        push @{ $rec->{tokens} }, [ 'TEXT', $space ];
        substr($rec->{rest}, 0, length($space), '');
        return 1;
    }
    return 0;
}

sub extract_comment {
    my $rec = shift;
    my ($comment) = $rec->{rest} =~ m/^(#[^\n]*\n)/;
    if (length($comment) > 0) {
        push @{ $rec->{tokens} }, [ 'COMMENT', $comment ];
        substr($rec->{rest}, 0, length($comment), '');
        return 1;
    }
    die "failed to read comment";
}

sub extract_unquted_string {
    my $rec = shift;
    # this is unquoted string. 
    my ($string) = $rec->{rest} =~ m/([A-Za-z]\w*)\s*=>/s;
    die "failed to parse unquted string: |".substr($rec->{rest}, 0, 40)."|" 
        unless defined $string;
    push @{ $rec->{tokens} }, ['STR', $string, '', ''];
    substr($rec->{rest}, 0, length($string), '');
    return 1;
}

sub extract_quated_string {
    my $rec = shift;
    my $sep = substr($rec->{rest}, 0, 1, '');
    my $string = '';
    while (1) {
        my ($start, $rest) = split $sep, $rec->{rest}, 2;
        die "failed to parse quoted string" unless defined $rest;
        $rec->{rest} = $rest;
        $string .= $start;
        my ($slashes) = $start =~ m/(\\*)$/;
        if (length($slashes) % 2 == 1) {
            # slashed seperator
            $string .= $sep;
            next;
        }
        push @{ $rec->{tokens} }, ['STR', $string, $sep, $sep];
        return 1;
    }
}

sub extract_quated_string_qq {
    my $rec = shift;
    my ($init, $sep) = $rec->{rest} =~ m/^(qq?)(.)/;
    substr($rec->{rest}, 0, length($init) + length($sep), '');
    my ($endsep, $search); 
    if (exists $seperators->{$sep}) {
        $endsep = $seperators->{$sep};
        $search = "[\\$sep\\$endsep]";
    }
    else {
        $search = quotemeta($sep);
    }
    $search = qr/($search)/;
    my $string = '';
    my $deep = 0;
    while (1) {
        my ($start, $char, $rest) = split $search, $rec->{rest}, 2;
        die "failed to parse quoted string" unless defined $rest;
        $rec->{rest} = $rest;
        $string .= $start;
        my ($slashes) = $start =~ m/(\\*)$/;
        if (length($slashes) % 2 == 1) {
            # slashed seperator
            $string .= $char;
            next;
        }
        if (defined $endsep) {
            if ($char eq $endsep) {
                if ($deep > 0) {
                    $deep--;
                    $string .= $char;
                    next;
                }
                else {
                    push @{ $rec->{tokens} }, ['STR', $string, $init.$sep, $endsep];
                    return 1;
                }
            }
            if ($char eq $sep) {
                $deep++;
                $string .= $char;
                next;
            }
        }
        elsif ($char eq $sep) {
            push @{ $rec->{tokens} }, ['STR', $string, $init.$sep, $sep];
            return 1;
        }
        die "should not reach here";
    }
}

sub parse {
    my ($class, $content) = @_;
    my @parts = split qr/(\%Lexicon\s*=\s*\()/sm, $content, 2;
    return unless scalar(@parts) == 3;
    my $rest = pop @parts;
    my $start = join '', @parts;
    @parts = ();
    my $rec= { tokens => [], rest => $rest, buf => $start };
    while (length($rec->{rest}) > 0) {
        next if extract_space($rec);
        if ( $rec->{rest} =~ m/^#/) {
            extract_comment($rec);
            next;
        }
        if ( $rec->{rest} =~ m/^('|")/ ) {
            extract_quated_string($rec);
            next;
        }
        if ( $rec->{rest} =~ m/^qq?./ ) {
            extract_quated_string_qq($rec);
            next;
        }
        if ( $rec->{rest} =~ m/^[A-Za-z]/) {
            # probably unquoted string. i.e. word => 'val'
            extract_unquted_string($rec);
            next;
        }
        if ( $rec->{rest} =~ m/^\)/) {
            # end of strings
            last;
        }
    }
    return $rec->{tokens};
}

my %pslash = (
    n => "\n",
    t => "\t",
    r => "\r",
    f => "\f",
    );

sub get_str_val {
    my $token = shift;
    return $token->[1] unless $token->[0] eq 'STR';
    my $str = $token->[1];
    $str =~ s/\\(.)/exists $pslash{$1} ? "\\".$1 : $1 /ge;
    return $str;
}

sub get_str_inter {
    my $token = shift;
    return $token->[1] unless $token->[0] eq 'STR';
    my $str = $token->[1];
    if ($token->[2] =~ m/^"|qq.$/) {
        $str =~ s/\\(.)/exists $pslash{$1} ? $pslash{$1} : $1 /ge;
    }
    elsif ($token->[2] =~ m/^q?([^q])$/) {
        my $sep = $1;
        my @list = ($sep, "\\");
        push @list, $seperators->{$sep} if exists $seperators->{$sep};
        $str =~ s/\\(.)/(grep { $1 eq $_ } @list) ? $1 : "\\".$1 /ge;
    }
    return $str;
}

1;
