from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0004_bin_capacity_profile_is_approved_employee_and_more')]
    operations = [migrations.AddField(model_name='reward', name='discount_percentage', field=models.FloatField(blank=True, null=True))]