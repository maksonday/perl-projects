Netcat
============================

Реализация утилиты netcat

Поддерживаемые флаги:
* `-p` - указывает исходный порт , который netcat должен использовать, с учетом ограничений привилегий и доступности.

* `-u` - использование UDP вместо TCP по умолчанию.

### Пример:

```sh
$ perl nc.pl -p 31337

$ perl nc.pl -u
```

Подробнее про ключи в `man netcat`
