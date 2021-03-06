DeepClone(Клонирование сложных структур данных)
====================================

clone - функция, принимающая на вход ссылку на какую либо структуру данных и отдающая, в качестве результата, ее точную независимую копию.
Это значит, что ни один элемент результирующей структуры не может ссылаться на элементы исходной, но при этом она должна в точности повторять ее схему.

Входные данные:
* undef
* строка
* число
* ссылка на массив
* ссылка на хеш
Элементами массивов и хешей могут быть любые из указанных выше конструкций.
Любые отличные от указанных типы данных -- недопустимы. В этом случае результатом клонирования должен быть undef.

Выходные данные:
* undef
* строка
* число
* ссылка на массив
* ссылка на хеш
В элементах массивов и хешей не могут быть ссылки на массивы и хеши исходной структуры данных.

Файлы:
* lib/DeepClone.pm - модуль с реализацией функции клонирования(clone)
* bin/clone - скрипт для проверки алгоритма
