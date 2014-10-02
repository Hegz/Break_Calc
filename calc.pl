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

my @Ice_Prime_Types = ('Barrier', 'Code Gate', 'Sentry', 'Trap', 'Mythic');

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
			# Add the ice subtypes to the breaker search list
			my @subtypes = (split(/ - /, $ICE{$_}->{subtype}));
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
			if ($ICE{$_}->{subtype} =~ m/$Prime/i){
				$is_Prime = 1;
			}
		}
		if ($is_Prime) {
		# Add in the Logical ICE, as well as the subtypes to the search list
			push @Prime_Ice, $ICE{$_};
			for (@{$ICE{$_}->{logicalsubtypes}}) {
				$ICE_Subtypes{$_} = 1;
			}
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
my @Prime_Breakers;
for my $breaker (keys %Breakers) {
	for my $subtype (keys %ICE_Subtypes) {
		if ($Breakers{$breaker}->{text} =~ m/\W$subtype\W/i) {
			push @Prime_Breakers, $Breakers{$breaker};
		}
	}
	if ($Breakers{$breaker}->{subtype} =~ m/AI/){
		push @Prime_Breakers, $Breakers{$breaker};
	}
}

@Prime_Breakers = sort { $a->{faction} cmp $b->{faction} or
							  $a->{title}   cmp $b->{title}
} @Prime_Breakers;

my @Breaker_Titles;
for (@Prime_Breakers){ 
	push @Breaker_Titles, $_->{title};
}

print "ICE Name";
unshift @Breaker_Titles, "Tax:Cost";
unshift @Breaker_Titles, "Average";
for (@Breaker_Titles){
	print ",$_";
}
print "\n";

@Prime_Ice = sort { $a->{faction} cmp $b->{faction} or
					  $a->{title}   cmp $b->{title}
} @Prime_Ice;


my %Average;
for my $ice (@Prime_Ice) {
	my $Ice_total_cost;
	my $Ice_total_broken;
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

BREAKER:	for my $breaker (@Prime_Breakers) {
		my $valid_Breaker = 0;
		for my $type (@subtypes) {
			if ($breaker->{text} =~ m/$type/i){
				$valid_Breaker = 1;
				last;
			}
		}
		$valid_Breaker = 1 if ($breaker->{subtype} =~ m/AI/);
		push @dataline, 'X' unless $valid_Breaker;
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
					push @dataline, 'X';
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
			if ($breaker->{title} eq 'Wyrm') {
				$cost += $strength;
			}
			$Average{$breaker->{title}}->{total} += $cost;
			$Average{$breaker->{title}}->{broken} += 1;
			push @dataline, $cost;
			$Ice_total_cost += $cost;
			$Ice_total_broken += 1;
		}
	}
	print shift @dataline;
	#print STDERR  "$ice->{title} (($Ice_total_cost / $Ice_total_broken) / $ice->{cost})\n";
	if ($ice->{cost} > 0) {
		unshift @dataline, sprintf "%.1f", ( ($Ice_total_cost / $Ice_total_broken) / $ice->{cost});
	}
	else {
		unshift @dataline, "Inf!";
	}
	unshift @dataline, sprintf "%.1f", ($Ice_total_cost / $Ice_total_broken);
	for (@dataline){
		print ",$_"
	}
	print "\n";
}
	print "Average";
	for (@Breaker_Titles) {
		if (defined $Average{$_}->{broken} && $Average{$_}->{broken} > 0){
			printf ",%.1f", $Average{$_}->{total} / $Average{$_}->{broken};
		}
		else {
			print ",";
		}
	}
print "\n\n";
}
