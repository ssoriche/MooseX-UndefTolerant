#!/usr/bin/env perl

use v5.12;

use Test::More tests => 2;

{
  package Foo;

  use Moose;
  use MooseX::UndefTolerant;

  our $error = 0;

  around BUILDARGS => sub {
    my ($orig, $self, @args) = @_;

    my $args = $self->$orig(@args);

    my $meta = Moose::Util::find_meta($self);
    for my $attr (sort { $a->insertion_order <=> $b->insertion_order } $meta->get_all_attributes) {
      next unless defined( my $init_arg = $attr->init_arg );

      if ($attr->is_required and 
        ! $attr->is_lazy and
        ! $attr->has_default and
        ! $attr->has_builder and
        ! exists $args->{$init_arg}) {
        $error = 1;
        next;
      }

      next unless exists $args->{$init_arg} && $attr->has_type_constraint;

      my $tc = $attr->type_constraint;
      my $value = $tc->has_coercion && $attr->should_coerce
          ? $tc->coerce($args->{$init_arg})
          : $args->{$init_arg};

      unless ($attr->verify_against_type_constraint($value)) {
        $error = 2;
        next;
      }
    }

    return $args;
  };
  

  has bar => (
    is       => 'ro',
    required => 1,
  );

  has baz => (
    is  => 'ro',
    isa => 'Int',
  );

  has error => (
    is => 'rw',
    isa => 'Int',
    default => 0,
  );

  no Moose;
}

my $foo = Foo->new({ bar => 1});
ok($foo,'object created');
is($Foo::error,0,'no errors during instantiation');

$foo = Foo->new({ bar => 1, baz => undef});
ok($foo,'object with undef attribute created');
is($Foo::error,0,'no errors during instantiation');

