from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0008_alter_activity_date_alter_bin_bin_id')]
    operations = [migrations.AlterField(model_name='activity', name='date', field=models.DateTimeField(auto_now_add=True)), migrations.AlterField(model_name='bin', name='bin_id', field=models.CharField(max_length=50, unique=True))]