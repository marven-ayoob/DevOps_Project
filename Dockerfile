# نستخدم nginx كـ base image علشان نعرض الـ static website
FROM nginx:alpine

# نحذف ملفات الـ default بتاعت nginx
RUN rm -rf /usr/share/nginx/html/*

# ننقل محتويات مشروع الـ static website لداخل مجلد nginx
COPY . /usr/share/nginx/html

# نعرض البورت 80
EXPOSE 80

# الأمر الإفتراضي لتشغيل nginx في الخلفية foreground عشان يبقي الكونتينر شغال
CMD ["nginx", "-g", "daemon off;"]
