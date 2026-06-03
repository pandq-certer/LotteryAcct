import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppErrorHandler {
  static String getLocalizedMessage(dynamic error) {
    if (error is PostgrestException) {
      return _mapPostgrestError(error);
    }
    if (error is AuthException) {
      return _mapAuthError(error);
    }
    return '操作失败，请稍后重试';
  }

  static String _mapPostgrestError(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return '记录已存在';
      case '23503':
        return '关联数据不存在';
      case '42501':
        return '没有权限执行此操作';
      default:
        return '数据操作失败';
    }
  }

  static String _mapAuthError(AuthException e) {
    if (e.message.contains('Invalid login credentials')) {
      return '用户名或密码错误';
    }
    if (e.message.contains('Email not confirmed')) {
      return '邮箱未验证';
    }
    return '认证失败';
  }

  static void showError(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getLocalizedMessage(error)),
        backgroundColor: const Color(0xFFFF3D57),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
