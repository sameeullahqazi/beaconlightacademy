abstract class APIDataSourceInterface {
  Future<Map<String, dynamic>> fetchData({
    String cookies = "",
    List<String>? params,
    bool shouldDownloadJson = false,
    String? userId,
    String? accessToken,
  });
}
