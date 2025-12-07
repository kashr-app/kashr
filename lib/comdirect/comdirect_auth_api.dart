import 'package:dio/dio.dart';
import 'package:finanalyzer/comdirect/comdirect_model.dart';
import 'package:retrofit/retrofit.dart';

part '../_gen/comdirect/comdirect_auth_api.g.dart';

@RestApi(baseUrl: "https://api.comdirect.de")
abstract class ComdirectAuthAPI {
  factory ComdirectAuthAPI(Dio dio, {String baseUrl}) = _ComdirectAuthAPI;

  @POST("/oauth/token")
  @FormUrlEncoded()
  Future<TokenDTO> createLoginAuthToken(
    @Body() CreateLoginAuthTokenReqDTO createLoginAuthTokenReqDTO,
  );

  @POST("/oauth/token")
  @FormUrlEncoded()
  Future<TokenDTO> createApiToken(
    @Body() ApiAccessTokenReqDTO apiAccessTokenReqDTO,
  );

  @DELETE("/oauth/revoke")
  @FormUrlEncoded()
  Future<HttpResponse<void>> revokeToken();

  @GET("/api/session/clients/user/v1/sessions")
  Future<List<SessionDTO>> getSessionStatus();

  @POST("/api/session/clients/user/v1/sessions/{sessionId}/validate")
  Future<HttpResponse<SessionDTO>> postSessionValidate({
    @Path() required String sessionId,
    @Body() required SessionDTO session,
  });

  @PATCH("/api/session/clients/user/v1/sessions/{sessionId}")
  Future<HttpResponse<SessionDTO>> activateSession({
    @Header("x-once-authentication-info") required String tanChallengeIdWrapper,
    @Path() required String sessionId,
    @Body() required SessionDTO session,
  });

  @GET("/api/session/v1/authentications/{authId}")
  Future<AuthStatus> getAuthStatus(@Path("authId") String authId);
}
