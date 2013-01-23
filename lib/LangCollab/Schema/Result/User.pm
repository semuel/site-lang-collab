use utf8;
package LangCollab::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LangCollab::Schema::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 token

  data_type: 'char'
  is_nullable: 0
  size: 20

=head2 data

  data_type: 'blob'
  is_nullable: 0

=head2 oauth

  data_type: 'blob'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "token",
  { data_type => "char", is_nullable => 0, size => 20 },
  "data",
  { data_type => "blob", is_nullable => 0 },
  "oauth",
  { data_type => "blob", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-01-21 17:53:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hk++jFjkx23eKJZ18wxgUQ

use Storable qw{nfreeze thaw};

sub oauth_token {
  my $self = shift;
  if (@_ > 0) {
    my $token = shift;
    $self->oauth(nfreeze($token->session_freeze()));
    return;
  }
  else {
    return thaw($self->oauth());
  }
}

sub user_data {
  my $self = shift;
  if (@_ > 0) {
    my $value = shift;
    $self->data(nfreeze($value));
    return;
  }
  else {
    return thaw($self->data());
  }
}


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
