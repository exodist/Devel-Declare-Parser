#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Exporter::Declare',
    license     => 'perl',
    dist_author => 'Chad Granum <exodist7@gmail.com>',
    create_readme => 1,
    requires => {
        'Test::Simple' => 0.88,
        'Test::Exception::LessClever' => 0,
        'Devel::Declare' => 0.006000,
        'B::Compiling' => 0.02,
        'B::Hooks::EndOfScope' => 0.08,
        'B::Hooks::OP::Check' => 0,
        'Devel::BeginLift' => 0,

    },
    meta_merge => {
        resources => {
            repository  => 'http://github.com/exodist/Exporter-Declare',
            bugtracker  => 'http://github.com/exodist/Exporter-Declare/issues',
        },
    }
);

$build->create_build_script;
