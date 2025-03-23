# 构建阶段
FROM node:18-alpine3.21 AS builder

RUN apk add --no-cache git python3 make g++ && \
    git config --global http.version HTTP/1.1

WORKDIR /app
RUN git clone https://github.com/davidlee6628/drpy-node.git . && \
    npm config set registry https://registry.npmmirror.com && \
    npm install -g pm2

ENV YARN_IGNORE_ENGINES=1
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN yarn install --production=false --network-timeout 300000 && \
    yarn add puppeteer && \
    rm -rf /usr/local/lib/node_modules/npm && \
    rm -rf /root/.npm /root/.cache

RUN mkdir -p /tmp/drpys && \
    cp -ra /app/. /tmp/drpys/

# 运行时阶段
FROM alpine:3.21

# 安装基础依赖和编译工具
RUN apk update && apk add --no-cache \
    nodejs \
    npm \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    python3 \
    make \
    g++ && \
    rm -rf /var/cache/apk/*

# 安装 PM2
RUN npm install -g pm2

# 安装中文字体
RUN mkdir -p /usr/share/fonts/noto-cjk && \
    wget -qO /tmp/NotoSansCJKsc-hinted.zip https://noto-website-2.storage.googleapis.com/pkgs/NotoSansCJKsc-hinted.zip && \
    unzip /tmp/NotoSansCJKsc-hinted.zip -d /usr/share/fonts/noto-cjk && \
    rm /tmp/NotoSansCJKsc-hinted.zip && \
    fc-cache -fv

# 配置证书
RUN ln -s /etc/ssl/certs /usr/local/share/ca-certificates && \
    update-ca-certificates

# 环境变量
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
    NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=512"

# 复制应用
WORKDIR /app
COPY --from=builder /tmp/drpys /app

# 权限配置
RUN adduser -D node -G root && \
    chown -R node:root /app && \
    chmod -R 775 /app

# 暴露端口和健康检查
EXPOSE 5757
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

# 启动命令
USER node
CMD ["pm2-runtime", "start", "index.js"]





