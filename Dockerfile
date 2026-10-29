FROM nginx:alpine

WORKDIR /app

RUN rm -rf /usr/share/nginx/html/*

COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/css/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

