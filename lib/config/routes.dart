import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/main_wrapper.dart';
import '../services/auth_service.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => MainWrapper(authService: AuthService()),
  '/login': (context) => LoginScreen(authService: AuthService()),
  '/register': (context) => RegisterScreen(authService: AuthService()),
  '/home': (context) => HomeScreen(authService: AuthService()),
};
