# ============================================
# Stage 1: Build
# ============================================
FROM node:20-alpine AS builder

WORKDIR /app

# نصب ابزارهای لازم برای build
RUN apk add --no-cache git python3 make g++

# ابتدا فقط فایل‌های وابستگی را کپی می‌کنیم تا cache داکر بهتر کار کند
COPY package*.json ./
COPY lerna.json* ./

# نصب وابستگی‌ها
RUN npm ci --no-audit --no-fund

# حالا بقیه سورس را کپی می‌کنیم
COPY . .

# بیلد پروژه (خروجی در پوشه build قرار می‌گیرد)
RUN npm run build

# ============================================
# Stage 2: Serve with Nginx
# ============================================
FROM nginx:1.27-alpine AS runtime

# حذف کانفیگ پیش‌فرض
RUN rm /etc/nginx/conf.d/default.conf

# کانفیگ اختصاصی برای SPA + gzip
COPY <<'EOF' /etc/nginx/conf.d/livecodes.conf
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # gzip برای کاهش حجم انتقال
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/wasm
        image/svg+xml;

    # هدرهای امنیتی پایه (مهم چون iframe و worker داریم)
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # کش طولانی برای فایل‌های هش‌دار
    location ~* \.(?:js|css|woff2?|ttf|eot|svg|png|jpg|jpeg|gif|ico|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # index.html نباید کش شود
    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
}
EOF

# کپی خروجی بیلد از stage قبل
COPY --from=builder /app/build /usr/share/nginx/html

# پورت پیش‌فرض (قابل override توسط Render)
ENV PORT=80
EXPOSE 80

# healthcheck ساده
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:${PORT}/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
