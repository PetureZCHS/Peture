import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import 'app_route_observer.dart';

mixin PageTrackerMixin<T extends StatefulWidget> on State<T>
    implements RouteAware {
  String get analyticsPageName;

  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => _reportStart();

  @override
  void didPopNext() => _reportStart();

  @override
  void didPop() => _reportEnd();

  @override
  void didPushNext() => _reportEnd();

  void _reportStart() => AnalyticsService.onPageStart(analyticsPageName);

  void _reportEnd() => AnalyticsService.onPageEnd(analyticsPageName);
}

class TrackedPage extends StatefulWidget {
  final String pageName;
  final Widget child;

  const TrackedPage({
    super.key,
    required this.pageName,
    required this.child,
  });

  @override
  State<TrackedPage> createState() => _TrackedPageState();
}

class _TrackedPageState extends State<TrackedPage> implements RouteAware {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => AnalyticsService.onPageStart(widget.pageName);

  @override
  void didPopNext() => AnalyticsService.onPageStart(widget.pageName);

  @override
  void didPop() => AnalyticsService.onPageEnd(widget.pageName);

  @override
  void didPushNext() => AnalyticsService.onPageEnd(widget.pageName);

  @override
  Widget build(BuildContext context) => widget.child;
}
