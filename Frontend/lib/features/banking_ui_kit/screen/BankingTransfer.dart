import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'BankingTransferSuccessful.dart';
import '../utils/BankingColors.dart';
import '../utils/BankingContants.dart';
import '../utils/BankingImages.dart';
import '../utils/BankingSlider.dart';
import '../utils/BankingStrings.dart';
import '../utils/BankingWidget.dart';

class BankingTransfer extends StatefulWidget {
  static var tag = "/BankingTransfer";

  @override
  _BankingTransferState createState() => _BankingTransferState();
}

class _BankingTransferState extends State<BankingTransfer> {
  bool isSwitch = false;
  bool isGetOtp = false;
  var tapCount = 0;

  void tappedConfirm() {
    if (tapCount != 1) {
      BankingTransferSuccessful().launch(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Banking_app_Background,
      body: Container(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              10.height,
              Text(
                isSwitch == true
                    ? Banking_lbl_Confirm_Transfer
                    : Banking_lbl_Transfer,
                style: primaryTextStyle(
                    color: Banking_TextColorPrimary,
                    size: 26,
                    fontFamily: fontBold),
              ),
              10.height,
              Text("Chọn tài khoản nguồn chuyển tiền",
                  style: primaryTextStyle(
                      color: Banking_TextColorSecondary,
                      size: 14,
                      fontFamily: fontBold)),
              16.height,
              BankingSliderWidget().visible(isSwitch == false),
              Container(
                margin: EdgeInsets.only(
                    left: spacing_standard_new, right: spacing_standard_new),
                child: Stack(
                  children: [
                    Image.asset(Banking_ic_CardImage,
                        fit: BoxFit.cover, height: 200),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("NF BANK USER",
                                    style: boldTextStyle(
                                        color: Banking_whitePureColor,
                                        size: 18,
                                        fontFamily: fontMedium))
                                .paddingOnly(
                                    top: spacing_large,
                                    left: spacing_standard_new),
                            Text(Banking_lbl_app_Name,
                                    style: boldTextStyle(
                                        color: Banking_whitePureColor,
                                        size: 16,
                                        fontFamily: fontMedium))
                                .paddingOnly(
                                    top: spacing_large,
                                    right: spacing_standard_new)
                          ],
                        ),
                        Text("Nội bộ NF Bank",
                                style: boldTextStyle(
                                    color: Banking_whitePureColor,
                                    size: 18,
                                    fontFamily: fontMedium))
                            .paddingOnly(
                                top: spacing_large, left: spacing_standard_new),
                        Text('9704 *** ** *** 8888',
                                style: boldTextStyle(
                                    color: Banking_whitePureColor,
                                    size: 18,
                                    fontFamily: fontMedium))
                            .paddingOnly(
                                left: spacing_standard_new,
                                top: spacing_control),
                        Text("50.000.000 đ",
                                style: boldTextStyle(
                                    color: Banking_whitePureColor,
                                    size: 18,
                                    fontFamily: fontMedium))
                            .paddingOnly(
                                top: spacing_standard,
                                left: spacing_standard_new),
                      ],
                    ),
                    10.height,
                  ],
                ),
              ).visible(isSwitch == true),
              16.height,
              Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  20.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Chọn Ngân hàng",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Row(
                        children: [
                          Text("Nội bộ NF Bank",
                              style: primaryTextStyle(
                                  color: Banking_TextColorPrimary,
                                  size: 16,
                                  fontFamily: fontRegular)),
                          Icon(Icons.keyboard_arrow_right,
                              size: 30, color: Banking_greyColor),
                        ],
                      ).onTap(
                        () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) => CustomDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  20.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Người thụ hưởng",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Row(
                        children: [
                          Text("Chọn từ danh bạ",
                              style: primaryTextStyle(
                                  color: Banking_TextColorPrimary,
                                  size: 16,
                                  fontFamily: fontRegular)),
                          Icon(Icons.keyboard_arrow_right,
                              size: 30, color: Banking_greyColor),
                        ],
                      ),
                    ],
                  ),
                  20.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Số tài khoản nhận",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Text("123 456 789",
                          style: primaryTextStyle(
                              color: Banking_TextColorPrimary,
                              size: 16,
                              fontFamily: fontRegular)),
                    ],
                  ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Ngân hàng",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Text(Banking_lbl_app_Name,
                          style: primaryTextStyle(
                              color: Banking_TextColorPrimary,
                              size: 16,
                              fontFamily: fontRegular)),
                    ],
                  ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Chi nhánh",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Text("TP. Hồ Chí Minh",
                          style: primaryTextStyle(
                              color: Banking_TextColorPrimary,
                              size: 16,
                              fontFamily: fontRegular)),
                    ],
                  ),
                  Divider(height: 24),
                  Text("Thông tin giao dịch",
                      style: primaryTextStyle(
                          color: Banking_TextColorSecondary,
                          size: 14,
                          fontFamily: fontRegular)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Số tiền",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Text("1.000.000 đ",
                          style: primaryTextStyle(
                              color: Banking_TextColorPrimary,
                              size: 16,
                              fontFamily: fontRegular)),
                    ],
                  ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Nội dung",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Text("Chuyen tien thanh toan",
                          style: primaryTextStyle(
                              color: Banking_TextColorPrimary,
                              size: 16,
                              fontFamily: fontRegular)),
                    ],
                  ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Phí giao dịch",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Text("0 đ (Miễn phí)",
                          style: primaryTextStyle(
                              color: Banking_TextColorPrimary,
                              size: 16,
                              fontFamily: fontRegular)),
                    ],
                  ),
                  Divider(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Mã OTP đã được gửi đến số điện thoại của bạn",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 14,
                              fontFamily: fontRegular)),
                      EditText(text: "Nhập mã OTP", isPassword: false),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(Banking_lbl_Resend,
                                style: primaryTextStyle(
                                    size: 18, fontFamily: fontRegular))
                            .onTap(() {}),
                      ),
                      8.height,
                      Text("Xác thực giao dịch bằng Face ID",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 14,
                              fontFamily: fontRegular)),
                      Image.asset(Banking_ic_face_id,
                              color: Banking_Primary, height: 40, width: 40)
                          .center()
                          .paddingOnly(top: 16, bottom: 16),
                    ],
                  ).visible(isGetOtp == true),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Lưu người thụ hưởng này",
                          style: primaryTextStyle(
                              color: Banking_TextColorSecondary,
                              size: 16,
                              fontFamily: fontRegular)),
                      Switch(
                        value: isSwitch,
                        onChanged: (value) {
                          setState(() {
                            isSwitch = value;
                            print(isSwitch);
                          });
                        },
                        activeTrackColor: Banking_Primary.withOpacity(0.5),
                        activeColor: Banking_Primary,
                      ),
                    ],
                  ).visible(isGetOtp == false),
                  Divider(height: 24),
                  16.height,
                  BankingButton(
                      textContent: isGetOtp == true
                          ? Banking_lbl_Confirm
                          : Banking_lbl_Get_OTP,
                      onPressed: () {
                        setState(
                          () {
                            isGetOtp = true;
                            tapCount = tapCount + 1;
                            tappedConfirm();
                          },
                        );
                      }).visible(isSwitch == true),
                  24.height,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0.0,
      backgroundColor: Colors.transparent,
      child: dialogContent(context),
    );
  }
}

dialogContent(BuildContext context) {
  return Container(
    padding: EdgeInsets.fromLTRB(8, 16, 8, 16),
    decoration: boxDecorationWithRoundedCorners(
        borderRadius: BorderRadius.circular(10),
        backgroundColor: Banking_whitePureColor),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        8.height,
        Text(Banking_lbl_Same_Bank,
                style: primaryTextStyle(
                    color: Banking_TextColorSecondary,
                    size: 16,
                    fontFamily: fontRegular))
            .onTap(() {
          finish(context);
        }),
        8.height,
        Divider(thickness: 1.0, color: Banking_greyColor.withOpacity(0.5)),
        8.height,
        Text(Banking_lbl_Other_Bank,
                style: primaryTextStyle(
                    color: Banking_TextColorSecondary,
                    size: 16,
                    fontFamily: fontRegular))
            .onTap(() {
          finish(context);
        }),
        8.height,
        Divider(thickness: 1.0, color: Banking_greyColor.withOpacity(0.5)),
        8.height,
        Text(Banking_lbl_Credit_Card,
                style: primaryTextStyle(
                    color: Banking_TextColorSecondary,
                    size: 16,
                    fontFamily: fontRegular))
            .onTap(() {
          finish(context);
        }),
        8.height,
      ],
    ),
  );
}
