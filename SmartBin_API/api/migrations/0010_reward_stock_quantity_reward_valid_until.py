from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0009_alter_activity_date_alter_bin_bin_id')]
    operations = [migrations.AddField(model_name='reward', name='stock_quantity', field=models.IntegerField(default=-1)), migrations.AddField(model_name='reward', name='valid_until', field=models.DateTimeField(blank=True, null=True))]