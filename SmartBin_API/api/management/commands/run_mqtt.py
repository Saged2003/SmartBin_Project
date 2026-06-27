from django.core.management.base import BaseCommand
from api.mqtt import start_mqtt

class Command(BaseCommand):
    def handle(self, *args, **kwargs):
        start_mqtt()