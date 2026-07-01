import json
from channels.generic.websocket import AsyncWebsocketConsumer

class MapConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        await self.channel_layer.group_add("map_updates", self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("map_updates", self.channel_name)

    async def bin_update(self, event):
        message = event['message']
        await self.send(text_data=json.dumps({
            'type': 'bin_update',
            'message': message
        }))

class UserConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.username = self.scope['url_route']['kwargs']['username']
        self.group_name = f"user_{self.username}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def user_update(self, event):
        message = event['message']
        await self.send(text_data=json.dumps({
            'type': 'user_update',
            'message': message
        }))