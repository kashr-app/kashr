import 'package:dio/dio.dart';
import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:retrofit/retrofit.dart';

part '../_gen/comdirect/comdirect_api.g.dart';

@RestApi(baseUrl: "https://api.comdirect.de/api")
abstract class ComdirectAPI {
  factory ComdirectAPI(Dio dio, {String baseUrl}) = _ComdirectAPI;

  @GET("/banking/clients/user/v2/accounts/balances")
  Future<AccountsPage> getBalances({
    /// first index to fetch
    @Query("paging-first") int index = 0,
    @Query("paging-count") int pageSize = 20,
  });

  @GET("/banking/v1/accounts/{accountId}/transactions")
  Future<TransactionsPage> getTransactions({
    @Path("accountId") required String accountId,
    @Query("min-bookingDate") required String minBookingDate,
    @Query("max-bookingDate") required String maxBookingDate,
    @Query("transactionState") String transactionState = "BOOKED",

    /// first index to fetch
    @Query("paging-first") int index = 0,
    @Query("paging-count") int pageSize = 20,
  });
}
