#!/usr/bin/env perl

use v5.12;

use Test::More tests => 11;
use Try::Tiny;

{
  package Foo;

  use Moose;
  use MooseX::UndefTolerant;
  use Try::Tiny;

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

      my $exception;
      try {
        $attr->verify_against_type_constraint($value);
      }
      catch {
        $error = 2;
      };

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
    predicate => 'has_baz',
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
is($Foo::error,0,'no errors during normal instantiation');

$foo = Foo->new({ bar => 1, baz => undef});
ok($foo,'object with undef attribute created');
is($Foo::error,0,'no errors during instantiation with undef attribute');
is($foo->baz,undef,'baz is not set');
is($foo->has_baz,'','has_baz is not set');

$foo = Foo->new({ bar => 1, baz =>  1 });
ok($foo,'object with correct type attribute created');
is($Foo::error,0,'no errors during instantiation');
ok($foo->baz,'baz is set');
ok($foo->has_baz,'has_baz is set');

my $exception;
try {
  $foo = Foo->new({ bar => 1, baz => 'one' });
}
catch {
  $exception = $_;
};
ok($exception,'exception received during instantiation');
