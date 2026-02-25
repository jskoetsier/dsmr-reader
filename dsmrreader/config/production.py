from dsmrreader.config.defaults import *

CACHES["default"]["TIMEOUT"] = 60

# Disable Django Toolbar.
MIDDLEWARE = list(MIDDLEWARE)
MIDDLEWARE.remove("debug_toolbar.middleware.DebugToolbarMiddleware")

INTERNAL_IPS = None

# Security Headers
# NOTE: Update ALLOWED_HOSTS with your actual domain(s) in production
# X_FRAME_OPTIONS = "DENY"  # Already set by django.middleware.clickjacking.XFrameOptionsMiddleware
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True

# Content Security Policy (CSP)
# Restricts sources for scripts, styles, images, fonts, etc.
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = (
    "'self'",
    "'unsafe-inline'",
)  # NOTE: See base.html for inline scripts that need removal
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'")  # NOTE: See base.html for inline styles
CSP_IMG_SRC = ("'self'", "data:", "https:")  # Allow HTTPS images and data URIs
CSP_FONT_SRC = ("'self'", "https:")  # Allow CDN fonts
CSP_CONNECT_SRC = ("'self'",)  # 限制 AJAX/fetch to same origin
CSP_FRAME_ANCESTORS = ("'none'",)  # Prevent clickjacking via iframes
CSP_BASE_URI = ("'self'",)
CSP_FORM_ACTION = ("'self'",)

# Referrer Policy
REFERRER_POLICY = "strict-origin-when-cross-origin"

# Remove ALLOWED_HOSTS wildcard vulnerability
# IMPORTANT: This must be set to your actual domain(s) in production
# Example: ALLOWED_HOSTS = ["your-domain.com", "api.your-domain.com"]
# Use environment variable DSMRREADER_ALLOWED_HOSTS=your-domain.com,api.your-domain.com
from decouple import config

ALLOWED_HOSTS = config(
    "DSMRREADER_ALLOWED_HOSTS",
    cast=lambda v: [s.strip() for s in v.split(",")],
    default=["localhost", "127.0.0.1"],
)
