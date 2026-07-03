#ifndef MTPROTO_PROXY_H
#define MTPROTO_PROXY_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/**
 * Запускает MTProto прокси.
 * @param host Адрес для приёма соединений (например "127.0.0.1")
 * @param port Порт для приёма соединений
 * @param dc_ips Строка с DC IP адресами в формате "1:ip1,2:ip2,..."
 * @param secret 32-символьный hex secret
 * @param verbose 1 для подробного логирования
 * @return 0 при успехе, -1 если уже запущен, -3 если bind не удался
 */
int StartProxy(const char* host, int port, const char* dc_ips, const char* secret, int verbose);

/**
 * Останавливает прокси.
 * @return 0 при успехе, -1 если не был запущен
 */
int StopProxy(void);

/**
 * Устанавливает размер пула WebSocket соединений (2-16).
 */
void SetPoolSize(int size);

/**
 * Устанавливает директорию для кэша Cloudflare proxy доменов.
 */
void SetCfProxyCacheDir(const char* cache_dir);

/**
 * Настраивает Cloudflare proxy.
 * @param enabled 1 включить, 0 выключить
 * @param priority 1 приоритетный режим
 * @param user_domain пользовательский домен или пустая строка
 */
void SetCfProxyConfig(int enabled, int priority, const char* user_domain);

/**
 * Устанавливает секрет прокси.
 * @param secret 32-символьный hex secret
 */
void SetSecret(const char* secret);

/**
 * Возвращает строку со статистикой.
 * Вызывающий должен освободить через FreeString().
 */
char* GetStats(void);

/**
 * Возвращает секрет с префиксом "dd".
 * Вызывающий должен освободить через FreeString().
 */
char* GetSecretWithPrefix(void);

/**
 * Освобождает строку, возвращённую библиотекой.
 */
void FreeString(char* p);

#ifdef __cplusplus
}
#endif

#endif /* MTPROTO_PROXY_H */