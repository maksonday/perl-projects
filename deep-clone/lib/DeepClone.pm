package DeepClone;

use 5.016;
use warnings;

=encoding UTF8

=head1 SYNOPSIS

Клонирование сложных структур данных

=head1 clone($orig)

Функция принимает на вход ссылку на какую либо структуру данных и отдаюет, в качестве результата, ее точную независимую копию.
Это значит, что ни один элемент результирующей структуры, не может ссылаться на элементы исходной, но при этом она должна в точности повторять ее схему.

Входные данные:
* undef
* строка
* число
* ссылка на массив
* ссылка на хеш
Элементами ссылок на массив и хеш, могут быть любые из указанных выше конструкций.
Любые отличные от указанных типы данных -- недопустимы. В этом случае результатом клонирования должен быть undef.

Выходные данные:
* undef
* строка
* число
* ссылка на массив
* ссылка на хеш
Элементами ссылок на массив или хеш, не могут быть ссылки на массивы и хеши исходной структуры данных.

=cut

sub clone {
	my $orig = shift;
	my $cloned;
	my $saved = shift;

	if (ref $orig eq 'ARRAY'){
		if (!exists $saved->{$orig}){
			my @arr = @{$orig};
			$saved->{$orig} = undef;
			my @tmp;
			for(@arr){
				push(@tmp, DeepClone::clone($_, $saved));
			}
			$cloned = \@tmp;
		}
		else { $cloned = $orig; }
	}
	elsif(ref $orig eq 'HASH'){
		if (!exists $saved->{$orig}){
			my %hash = %{$orig};
			$saved->{$orig} = undef;
			my %tmp;
			while (my ($k, $v) = each %hash){
				$tmp{$k} = DeepClone::clone($v, $saved);
			}
			$cloned = \%tmp;
		}
		else { $cloned = $orig; }
	}
	elsif(ref \$orig eq 'SCALAR'){
		$cloned = $orig;
	}
	else { $cloned = undef; }

	return $cloned;
}

1;
