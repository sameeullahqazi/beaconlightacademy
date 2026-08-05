class APIStrings {
  static var env =
      "prod"; // local for local,dev for staging, prod for US, mex for Mexico
  static var myinkiqUrl = env == "local"
      ? "http://10.0.2.2/schoolmanagement" // ? "http://localhost/schoolmanagement"
      : (env == "dev"
          ? "https://staging.beaconlightacademy.edu.pk"
          : "https://web.beaconlightacademy.edu.pk");
  static var s3BucketName =
      env == "dev" ? 'bla-app-assets-staging' : 'bla-app-assets-2025';
  static var s3BucketUrl = "https://$s3BucketName.s3.ap-south-1.amazonaws.com";
  static var baseUrl = "$myinkiqUrl/restapi.php";
  // static var reportUrl = "https://$myinkiqUrl/birt/frameset?";
  static const loginAPI = "login";
  static const getDiaries = "diaryList";
  static const getCorrespondences = "correspondencesList";
  static const postUser = "postUser";
  static const getKeepUserLoggedIn = "keep";
}
