# ============================================
# Stage 1: Build
# ============================================
FROM node:20-alpine AS builder

WORKDIR /app

# نصب ابزارهای لازم برای build
RUN apk add --no-cache git python3 make g++

# کپی فایل‌های وابستگی
COPY package*.json ./
COPY lerna.json* ./

# نصب وابستگی‌ها با npm install (جایگزین npm ci)
RUN npm install --no-audit --no-fund

# کپی بقیه سورس
COPY . .

# بیلد پروژه
RUN npm run build

# ============================================
# Stage 2: Serve with Nginx
# ============================================
FROM nginx:1.27-alpine AS runtime

# حذف کانفیگ پیش‌فرض
RUN rm /etc/nginx/conf.d/default.conf

# کانفیگ اختصاصی برای SPA
COPY <<'EOF' /etc/nginx/conf.d/livecodes.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/plain text/css application/javascript application/json application/wasm image/svg+xml;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(?:js|css|woff2?|ttf|eot|svg|png|jpg|jpeg|gif|ico|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# کپی خروجی بیلد
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
