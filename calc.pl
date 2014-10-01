#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: cacl.pl
#
#        USAGE: ./cacl.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Adam Fairbrother (Hegz), afairbrother@sd73.bc.ca
# ORGANIZATION: School District No. 73
#      VERSION: 1.0
#      CREATED: 14-09-30 09:04:38 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use JSON;
use Data::Dumper;

my $perl_scalar;
{
	local $/;
	open my $data, '<', 'cards.json';
	my $json_text = <$data>;
	$perl_scalar = decode_json( $json_text );
}

my %ICE;
my %Breakers;

for my $card (@{$perl_scalar->{cards}}) {
	if ($card->{type} eq 'ICE') {
		$ICE{$card->{title}} = $card;
	}
	elsif ($card->{type} eq 'Program') {
		if ($card->{subtype} =~ m/Icebreaker/) {
			$Breakers{$card->{title}} = $card;
		}
	}
}

my @Ice_Prime_Types = ('Barrier', 'Code Gate', 'Sentry');

for my $Prime (@Ice_Prime_Types) {
my @Prime_Ice;
my %ICE_Subtypes;
for (keys %ICE) {
	if (($ICE{$_}->{subtype} =~ m/$Prime/i) || (defined $ICE{$_}->{logicalsubtypes})){
	# Check the primary subtypes and logical subtypes of this ice
		my $is_Prime;
		unless (defined $ICE{$_}->{logicalsubtypes}){
			# This is the correct type
			push @Prime_Ice, $ICE{$_};
			delete $ICE{$_};

			# Add the ice subtypes to the breaker search list
			my @subtypes = split(/ - /, $ICE{$_}->{subtypes});
			for (@subtypes) {
				$ICE_Subtypes{$_} = 1;
			}
		}
		if (defined $ICE{$_}->{logicalsubtypes}) {
			for (@{$ICE{$_}->{logicalsubtypes}}){
				if ($_ =~ m/$Prime/i) {
				# The logical subtype is correct, set the flag
					$is_Prime = 1;
				}
			}
			if ($ICE{$_}->{subtype} =~ m/trap/i || $ICE{$_}->{subtype} =~ m/mythic/i){
				$is_Prime = 0;
			}
		}
		if ($is_Prime) {
		# Add in the Logical ICE, as well as the subtypes to the search list
			push @Prime_Ice, $ICE{$_};
			for (@{$ICE{$_}->{logicalsubtypes}}) {
				$ICE_Subtypes{$_} = 1;
			}
			delete $ICE{$_};
		}
	}
}

# Remove the other primary types from this set
my @Removed_Types = @Ice_Prime_Types;
my $index = 0;
$index++ until $Removed_Types[$index] eq $Prime;
splice(@Removed_Types, $index, 1);

for (@Removed_Types) {
	delete $ICE_Subtypes{$_};
}

# Search the Breakers for the correct subtypes
my @Barrier_Breakers;
for my $breaker (@Breakers) {
	for my $subtype (keys %Barrier_Subtypes) {
		if ($breaker->{text} =~ m/\W$subtype\W/i) {
			print STDERR $breaker->{title} . "\n";
			push @Barrier_Breakers, $breaker;
		}
	}
	if ($breaker->{subtype} =~ m/AI/){
		push @Barrier_Breakers, $breaker;
	}
}

@Barrier_Breakers = sort { $a->{faction} cmp $b->{faction} or
							  $a->{title}   cmp $b->{title}
} @Barrier_Breakers;

my @Breaker_Titles;
for (@Barrier_Breakers){ 
	push @Breaker_Titles, $_->{title};
}

@Barriers = sort { $a->{faction} cmp $b->{faction} or
					  $a->{title}   cmp $b->{title}
} @Barriers;


for my $ice (@Barriers) {
	my @dataline;
	push @dataline, $ice->{title};
	my $strength = $ice->{strength};

	# Count Subroutines 
	my $subs = () =  $ice->{text} =~ /\[Subroutine\]/g;

	# Build list of valid Subtypes
	my @subtypes = split(/ - /, $ice->{subtype});
	if (defined $ice->{logicalsubtypes}){
		for (@{$ice->{logicalsubtypes}}) {
			push @subtypes, $_;
		}
	}

BREAKER:	for my $breaker (@Barrier_Breakers) {
		my $valid_Breaker = 0;
		for my $type (@subtypes) {
			if ($breaker->{text} =~ m/$type/i){
				$valid_Breaker = 1;
				last;
			}
		}
		$valid_Breaker = 1 if ($breaker->{subtype} =~ m/AI/);
		push @dataline, '-' unless $valid_Breaker;
		if ($valid_Breaker) {
			my $breaker_str = $breaker->{strength};
			my $broken_subs = 0;
			my $cost = 0;
			while ( $breaker_str < $strength) {
				if (ref $breaker->{strengthcost} eq ref {}) {
					$breaker_str += $breaker->{strengthcost}->{strength};
					$cost += $breaker->{strengthcost}->{credits};
				}
				elsif (defined $breaker->{strengthcost}) {
					$breaker_str += 1;
					$cost += $breaker->{strengthcost};
				}
				elsif (defined $breaker->{variablestrength}){
					$cost += $strength - $breaker_str;
					$breaker_str = $strength;
				}
				else {
					push @dataline, '-';
					next BREAKER;
				}
			}
			while ( $subs > $broken_subs ) {
				if ($breaker->{breakcost}->{subroutines} eq 'all') {
					$broken_subs = 99;
				}
				else {
					$broken_subs += $breaker->{breakcost}->{subroutines};
				}
				$cost += $breaker->{breakcost}->{credits};
			}
			push @dataline, $cost;
		}
	}
	print shift @dataline;
	for (@dataline){
		print ",$_"
	}
	print "\n";
}
}
