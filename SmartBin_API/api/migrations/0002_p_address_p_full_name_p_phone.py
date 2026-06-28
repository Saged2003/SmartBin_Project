from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0001_initial')]
    operations = [migrations.AddField(model_name='p', name='address', field=models.CharField(blank=True, max_length=200, null=True)), migrations.AddField(model_name='p', name='full_name', field=models.CharField(blank=True, max_length=100, null=True)), migrations.AddField(model_name='p', name='phone', field=models.CharField(blank=True, max_length=20, null=True))]