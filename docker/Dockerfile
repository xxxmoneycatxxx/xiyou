FROM php:7.4-apache

# 安装 PHP 扩展 + mysql 客户端（用于 entrypoint 等待/导表）
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-mysql-client \
    libcurl4-openssl-dev \
    libonig-dev \
    && docker-php-ext-install pdo_mysql curl bcmath mbstring opcache \
    && docker-php-ext-enable curl \
    && a2enmod rewrite deflate expires \
    && rm -rf /var/lib/apt/lists/*

# Apache 双端口监听（容器内 CURL 走 8080，外部映射走 80）
RUN sed -i 's/Listen 80/Listen 80\nListen 8080/' /etc/apache2/ports.conf

# 站点配置：.htaccess 生效 + 禁止访问 .ini 文件
RUN { \
    echo '<VirtualHost *:80>'; \
    echo '  DocumentRoot /var/www/html'; \
    echo '  <Directory /var/www/html>'; \
    echo '    AllowOverride All'; \
    echo '    Require all granted'; \
    echo '  </Directory>'; \
    echo '  <Files ~ "\.ini$">'; \
    echo '    Require all denied'; \
    echo '  </Files>'; \
    echo '  # Gzip 压缩'; \
    echo '  AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json application/xml'; \
    echo '  # 静态资源浏览器缓存（30天）'; \
    echo '  ExpiresActive On'; \
    echo '  ExpiresByType image/jpeg "access plus 30 days"'; \
    echo '  ExpiresByType image/png "access plus 30 days"'; \
    echo '  ExpiresByType image/gif "access plus 30 days"'; \
    echo '  ExpiresByType image/webp "access plus 30 days"'; \
    echo '  ExpiresByType text/css "access plus 30 days"'; \
    echo '  ExpiresByType application/javascript "access plus 30 days"'; \
    echo '</VirtualHost>'; \
    echo '<VirtualHost *:8080>'; \
    echo '  DocumentRoot /var/www/html'; \
    echo '  <Directory /var/www/html>'; \
    echo '    AllowOverride All'; \
    echo '    Require all granted'; \
    echo '  </Directory>'; \
    echo '  <Files ~ "\.ini$">'; \
    echo '    Require all denied'; \
    echo '  </Files>'; \
    echo '  # Gzip 压缩'; \
    echo '  AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json application/xml'; \
    echo '  # 静态资源浏览器缓存（30天）'; \
    echo '  ExpiresActive On'; \
    echo '  ExpiresByType image/jpeg "access plus 30 days"'; \
    echo '  ExpiresByType image/png "access plus 30 days"'; \
    echo '  ExpiresByType image/gif "access plus 30 days"'; \
    echo '  ExpiresByType image/webp "access plus 30 days"'; \
    echo '  ExpiresByType text/css "access plus 30 days"'; \
    echo '  ExpiresByType application/javascript "access plus 30 days"'; \
    echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/000-default.conf

# PHP 性能配置
COPY docker/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/gzip.ini /usr/local/etc/php/conf.d/gzip.ini

# 容器初始化脚本（sed 修复 Windows CRLF）
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
