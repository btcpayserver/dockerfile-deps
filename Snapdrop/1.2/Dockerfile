FROM node:22-bullseye

RUN apt-get update && apt-get install -y git supervisor nginx && rm -rf /var/lib/apt/lists/*
WORKDIR /home/node/app
RUN git clone --depth 1 https://github.com/NicolasDorier/snapdrop -b 1.2 . && \
    cp -r /home/node/app/client/* /usr/share/nginx/html/
WORKDIR /home/node/app/server
RUN npm i

COPY supervisor-conf/*.conf /etc/supervisor/conf.d/
COPY sites-available/*.conf /etc/nginx/sites-available/

RUN groupadd services && \
    usermod -a -G services www-data && \
    usermod -a -G services node && \
    chown -R :services /var/log/supervisor/ && \
    chmod -R 770 /var/log/supervisor/ && \
    chown -R www-data /var/lib/nginx && \
    chown -R www-data /usr/share/nginx/html && \
    rm -rf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/

ENTRYPOINT [ "supervisord" ]