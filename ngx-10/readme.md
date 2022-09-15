Цель - собрать deb-пакет `nginx 1.18.0` со статическим модулем `nginx_upstream_check_module` используя `docker`-контейнер и попрактироваться в использовании этого модуля. Модуль `nginx_upstream_check_module` позволяет исключать серверы из балансировки, если они возвращают некорректный код ответа.

Пакет собирается на отдельном хосте из группы `runner` (на отдельном билд-сервере).

Полученный пакет установить на ВМ, настроить проксирование на 2 бэкенд-сервера, причем `nginx` должен каждую секунду опрашивать состояние серверов, делая запрос на страницу состояния (`/status`).

Дополнительно подключить динамический модуль `geoip2` и прокидывать на бэкенд двухбуквенный код страны клиента с помощью заголовка `X-Country`.