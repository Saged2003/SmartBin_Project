from django.urls import path
from . import views

urlpatterns = [
    path('register/', views.register_user),
    path('login/', views.login_user),
    path('profile/', views.get_profile),
    path('update-profile/', views.update_profile),

    path('validate-session/', views.validate_session),
    path('activities/', views.get_activities),
    path('rewards/', views.get_rewards),
    path('redeem-reward/', views.redeem_reward),
    path('redemption-history/', views.get_redemption_history),
    path('approve-employee/', views.approve_employee),
    path('esp/get-code/', views.esp_get_code),
    path('esp/check-scan/', views.esp_check_scan),
    path('esp/end-session/', views.esp_end_session),
    path('esp/update-capacity/', views.esp_update_capacity),

    path('user/scan-qr/', views.user_scan_qr),
    path('employee/update-location/', views.employee_update_location),
    path('bins/', views.get_all_bins),
    path('dashboard/stats/', views.dashboard_stats),
    path('leaderboard/', views.get_leaderboard),
    path('sync-ble-offline/', views.sync_ble_offline),
]