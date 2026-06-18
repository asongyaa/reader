import 'package:anx_reader/main.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AnxToast {
  static FToast fToast = FToast();

  static void init(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fToast.init(context);
    });
  }

  static void show(String message, {Icon? icon, int duration = 2000}) {
    Widget toast = FilledContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon ??
              Icon(Icons.info_outline,
                  size: 18,
                  color: Theme.of(navigatorKey.currentContext!)
                      .colorScheme
                      .onSurface),
          const SizedBox(width: 10.0),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(navigatorKey.currentContext!)
                    .colorScheme
                    .onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    // close previous toast
    fToast.removeQueuedCustomToasts();

    fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: Duration(milliseconds: duration),
    );
  }
}
