import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/fast_cache_progress_data.dart';

class FastCachedImage extends StatefulWidget {
  final String url;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget Function(BuildContext, FastCachedProgressData)? loadingBuilder;
  final Duration fadeInDuration;
  final double? width;
  final double? height;
  final double scale;
  final Color? color;
  final Animation<double>? opacity;
  final FilterQuality filterQuality;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool isAntiAlias;
  final bool disableErrorLogs;

  const FastCachedImage({
    required this.url,
    this.scale = 1.0,
    this.errorBuilder,
    this.semanticLabel,
    this.loadingBuilder,
    this.excludeFromSemantics = false,
    this.disableErrorLogs = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    this.fadeInDuration = const Duration(milliseconds: 500),
    Key? key,
  }) : super(key: key);

  @override
  State<FastCachedImage> createState() => _FastCachedImageState();
}

class _FastCachedImageState extends State<FastCachedImage>
    with TickerProviderStateMixin {
  late FastCachedProgressData _progressData;
  late Animation<double> _animation;
  late AnimationController _animationController;
  Uint8List? _imageData;
  String? _error;
  final String _boxName = 'imageCacheBox';
  late Box<Uint8List> _cacheBox;

  @override
  void initState() {
    super.initState();
    _initialize();
    _checkAndLoadImage();
  }

  void _initialize() async {
    _animationController =
        AnimationController(vsync: this, duration: widget.fadeInDuration);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _progressData = FastCachedProgressData(
      progressPercentage: ValueNotifier(0),
      totalBytes: null,
      downloadedBytes: 0,
      isDownloading: false,
    );
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox<Uint8List>(_boxName);
  }

  Future<void> _checkAndLoadImage() async {
    if (await _isCached(widget.url)) {
      _setImageData(_cacheBox.get(widget.url));
    } else {
      _fetchAndCacheImage();
    }
  }

  Future<bool> _isCached(String url) async {
    return _cacheBox.containsKey(url);
  }

  Future<void> _fetchAndCacheImage() async {
    try {
      Response response = await Dio().get(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (int received, int total) {
          if (!mounted) return;
          setState(() {
            _progressData.downloadedBytes = received;
            _progressData.totalBytes = total;
            _progressData.progressPercentage.value = received / total;
          });
        },
      );

      if (response.statusCode == 200) {
        Uint8List imageData = response.data;
        await _cacheBox.put(widget.url, imageData);
        _setImageData(imageData);
      } else {
        _setError('Error: Image couldn\'t be loaded.');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setImageData(Uint8List? data) {
    if (!mounted || data == null) return;
    setState(() {
      _imageData = data;
      _animationController.forward();
    });
  }

  void _setError(String error) {
    if (!mounted) return;
    setState(() {
      _error = error;
      if (!widget.disableErrorLogs) debugPrint(error);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cacheBox.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (_error != null && widget.errorBuilder != null) {
      imageWidget = widget.errorBuilder!(
          context, Object(), StackTrace.fromString(_error!));
    } else if (_imageData != null) {
      imageWidget = FadeTransition(
        opacity: _animation,
        child: Image.memory(
          _imageData!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          color: widget.color,
          colorBlendMode: widget.colorBlendMode,
          alignment: widget.alignment,
          repeat: widget.repeat,
          centerSlice: widget.centerSlice,
          matchTextDirection: widget.matchTextDirection,
          gaplessPlayback: widget.gaplessPlayback,
          isAntiAlias: widget.isAntiAlias,
          filterQuality: widget.filterQuality,
        ),
      );
    } else {
      imageWidget = widget.loadingBuilder != null
          ? widget.loadingBuilder!(context, _progressData)
          : const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: imageWidget,
    );
  }
}
