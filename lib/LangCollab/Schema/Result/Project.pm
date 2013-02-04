use utf8;
package LangCollab::Schema::Result::Project;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LangCollab::Schema::Result::Project

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<project>

=cut

__PACKAGE__->table("project");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 url

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 owner

  data_type: 'integer'
  is_nullable: 0

=head2 resp_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 master_branch

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 dev_branch

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 main_lang

  data_type: 'char'
  is_nullable: 0
  size: 2

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "url",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "owner",
  { data_type => "integer", is_nullable => 0 },
  "resp_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "master_branch",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "dev_branch",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "main_lang",
  { data_type => "char", is_nullable => 0, size => 2 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-02-04 14:59:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kjNJictD4WtbaGcODgVbOA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
