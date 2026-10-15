import '../model/BankingModel.dart';
import 'BankingColors.dart';
import 'BankingImages.dart';

List<BankingShareInfoModel> bankingInfoList() {
  List<BankingShareInfoModel> list = [];

  var list1 = BankingShareInfoModel(Banking_ic_Skype);
  list.add(list1);

  var list2 = BankingShareInfoModel(Banking_ic_Inst);
  list.add(list2);

  var list3 = BankingShareInfoModel(Banking_ic_WhatsApp);
  list.add(list3);

  var list4 = BankingShareInfoModel(Banking_ic_messenger);
  list.add(list4);

  var list5 = BankingShareInfoModel(Banking_ic_facebook);
  list.add(list5);

  return list;
}

List<BankingShareInfoModel> bankingNewsList() {
  List<BankingShareInfoModel> list = [];

  var list1 = BankingShareInfoModel(Banking_ic_walk1);
  list.add(list1);

  var list2 = BankingShareInfoModel(Banking_ic_walk2);
  list.add(list2);

  var list3 = BankingShareInfoModel(Banking_ic_walk3);
  list.add(list3);

  return list;
}

List<BankingQuesAnsModel> bankingQuestionList() {
  List<BankingQuesAnsModel> list = [];

  var list1 = BankingQuesAnsModel("Làm sao để đăng ký dịch vụ Ngân hàng số NF Bank?");
  list.add(list1);

  var list2 = BankingQuesAnsModel("Chương trình hoàn tiền khi mua sắm bằng thẻ NF Bank?");
  list.add(list2);

  var list3 = BankingQuesAnsModel("Quy trình thanh toán trực tuyến có an toàn và bảo mật không?");
  list.add(list3);

  var list4 = BankingQuesAnsModel("Chính sách ưu đãi quà tặng dành cho khách hàng mới?");
  list.add(list4);

  var list5 = BankingQuesAnsModel("Hạn mức chuyển tiền tối đa trong ngày là bao nhiêu?");
  list.add(list5);

  return list;
}

List<BankingSavingModel> bankingSavingList() {
  List<BankingSavingModel> list = [];

  var list1 = BankingSavingModel(
      title: "Sổ tiết kiệm tích lũy #1",
      date: "15/05/2026",
      rs: "50.000.000 đ",
      interest: "Lãi suất 6.5% - Kỳ hạn 12 Tháng");
  list.add(list1);

  var list2 = BankingSavingModel(
      title: "Sổ tiết kiệm Online #2",
      date: "10/08/2026",
      rs: "20.000.000 đ",
      interest: "Lãi suất 5.2% - Kỳ hạn 6 Tháng");
  list.add(list2);

  return list;
}

List<BankingPaymentModel> bankingPaymentList() {
  List<BankingPaymentModel> list = [];

  var list1 = BankingPaymentModel(
      title: "Thanh toán Tiền điện",
      img: Banking_ic_Electricity,
      color: Banking_Primary);
  list.add(list1);

  var list2 =
      BankingPaymentModel(title: "Thanh toán Tiền nước", img: Banking_ic_WaterDrop);
  list.add(list2);

  var list3 = BankingPaymentModel(
      title: "Thanh toán Internet / TV",
      img: Banking_ic_Website,
      color: Banking_blueColor);
  list.add(list3);

  var list4 = BankingPaymentModel(
      title: "Nạp tiền Điện thoại", img: Banking_ic_Mobile, color: Banking_palColor);
  list.add(list4);

  var list5 = BankingPaymentModel(
      title: "Thanh toán Nạp Game / App Store",
      img: Banking_ic_apple,
      color: Banking_greyColor);
  list.add(list5);

  var list6 = BankingPaymentModel(
      title: "Mua vé Xem phim",
      img: Banking_ic_Ticket,
      color: Banking_RedColor);
  list.add(list6);

  var list7 = BankingPaymentModel(
      title: "Mua vé Tàu hỏa",
      img: Banking_ic_Train,
      color: Banking_blueColor);
  list.add(list7);

  var list8 = BankingPaymentModel(
      title: "Đặt vé Máy bay", img: Banking_ic_plane, color: Banking_palColor);
  list.add(list8);

  var list9 = BankingPaymentModel(
      title: "Mua sắm Online",
      img: Banking_ic_ShoppingCart,
      color: Banking_Primary);
  list.add(list9);

  var list10 = BankingPaymentModel(
      title: "Đặt phòng Khách sạn",
      img: Banking_ic_Hotel,
      color: Banking_greenLightColor);
  list.add(list10);

  return list;
}

List<BankingPaymentModel> bankingPaymentDetailList() {
  List<BankingPaymentModel> list = [];

  var list1 = BankingPaymentModel(
      title: "Thanh toán Hóa đơn mới", img: Banking_ic_Voice, color: Banking_Primary);
  list.add(list1);

  var list2 = BankingPaymentModel(
      title: "Xem Lịch sử Thanh toán", img: Banking_ic_History);
  list.add(list2);

  return list;
}

List<BankingCardModel> bankingCardList() {
  List<BankingCardModel> list = [];
  var list1 = BankingCardModel(
      name: "Tài khoản Thanh toán", bank: "Nội bộ NF Bank", rs: "50.000.000 đ");
  list.add(list1);

  var list2 =
      BankingCardModel(name: "NGUYEN VAN A", bank: "Vietcombank", rs: "15.000.000 đ");
  list.add(list2);

  var list3 = BankingCardModel(
      name: "TRAN THI B", bank: "MB Bank", rs: "8.500.000 đ");
  list.add(list3);

  return list;
}

List<BankingPaymentHistoryModel> bankingHistoryList1() {
  List<BankingPaymentHistoryModel> list = [];

  var list1 = BankingPaymentHistoryModel(
      title: "Thanh toán Hóa đơn điện #7783", rs: "-500.000 đ");
  list.add(list1);

  var list2 = BankingPaymentHistoryModel(
      title: "Thanh toán Internet FPT #S1244", rs: "-350.000 đ");
  list.add(list2);

  return list;
}

List<BankingRateInfoModel> bankingRateInformationList() {
  List<BankingRateInfoModel> list = [];

  var list1 = BankingRateInfoModel(
      currency: "USD", flag: Banking_ic_USD, buy: "25.200", sell: "25.550");
  list.add(list1);

  var list2 = BankingRateInfoModel(
      currency: "EUR", flag: Banking_ic_Euro, buy: "27.100", sell: "27.800");
  list.add(list2);

  var list3 = BankingRateInfoModel(
      currency: "JPY", flag: Banking_ic_Yen, buy: "165.5", sell: "172.0");
  list.add(list3);

  var list4 = BankingRateInfoModel(
      currency: "CNY", flag: Banking_ic_CNY, buy: "3.480", sell: "3.620");
  list.add(list4);

  return list;
}

List<BankingHomeModel> bankingHomeList1() {
  List<BankingHomeModel> list = [];
  var list1 = BankingHomeModel(
      title: "Tài khoản Thanh toán", color: Banking_BalanceColor, bal: "+1.000.000 đ");
  list.add(list1);

  var list2 = BankingHomeModel(
      title: "Chuyển tiền cho NGUYEN VAN A", color: Banking_Primary, bal: "-500.000 đ");
  list.add(list2);

  return list;
}

List<BankingHomeModel2> bankingHomeList2() {
  List<BankingHomeModel2> list = [];
  var list1 = BankingHomeModel2(
      title: "Chuyển tiền nội bộ NF Bank",
      subTitle: "Miễn phí 100% tất cả giao dịch",
      icon: Banking_ic_Transfer,
      charge: "Miễn phí",
      color: Banking_Primary);
  list.add(list1);

  var list2 = BankingHomeModel2(
      title: "Nạp tiền điện thoại chiết khấu 5%",
      subTitle: "Nạp ngay nhận ưu đãi tức thì",
      icon: Banking_ic_Mobile,
      charge: "Ưu đãi 5%",
      color: Banking_blueColor);
  list.add(list2);

  return list;
}

List<BankingLocationModel> bankingLocationList() {
  List<BankingLocationModel> list = [];
  list.add(BankingLocationModel(
      title: "Chi nhánh Quận 1", location: "123 Lê Lợi, P. Bến Nghé, Q. 1, TP. Hồ Chí Minh", m: "500m"));
  list.add(BankingLocationModel(
      title: "Chi nhánh Ba Đình", location: "45 Kim Mã, P. Kim Mã, Q. Ba Đình, Hà Nội", m: "1.2km"));
  list.add(BankingLocationModel(
      title: "Chi nhánh Hải Châu", location: "88 Nguyễn Văn Linh, Q. Hải Châu, Đà Nẵng", m: "2.5km"));
  return list;
}
