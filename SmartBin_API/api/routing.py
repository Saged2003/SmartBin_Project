from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/map/$', consumers.MapConsumer.as_asgi()),
    re_path(r'ws/user/(?P<username>\w+)/$', consumers.UserConsumer.as_asgi()),
]