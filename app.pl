#!/opt/local/bin/perl
use Mojolicious::Lite;

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

app->start;

1;
