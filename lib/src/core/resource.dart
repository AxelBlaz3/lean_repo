enum SourceType {
  none, // Initial state
  cache, // Data came from local storage
  network, // Data came from the API
}

class Resource<T> {
  final T? data;
  final Object? error;
  final SourceType source;

  // Helper getters for cleaner UI code
  bool get isLoading => data == null && error == null;
  bool get isError => error != null;
  bool get hasData => data != null;

  const Resource({this.data, this.error, this.source = SourceType.none});

  /// Factory for the loading state
  factory Resource.loading() {
    return const Resource(source: SourceType.none);
  }

  /// Factory for success
  factory Resource.success(T data, SourceType source) {
    return Resource(data: data, source: source);
  }

  /// Factory for error
  factory Resource.failed(Object error, {T? data}) {
    // We allow passing `data` even on error (e.g. keeping old cache visible)
    return Resource(error: error, data: data, source: SourceType.none);
  }
}
