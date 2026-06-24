import { NextResponse } from 'next/server';

export async function GET(request, { params }) {
  // Lấy action: 'confirm' hoặc 'reject' từ URL động
  const { action } = await params;
  const { searchParams } = new URL(request.url);
  const token = searchParams.get('token');

  if (!token) {
    return new NextResponse('<h1>Lỗi: Thiếu token xác thực</h1>', {
      status: 400,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    });
  }

  try {
    // Gọi trực tiếp Go Backend ở local máy tính
    const backendUrl = `http://localhost:8080/api/v1/auth/device-verification/${action}?token=${token}`;
    console.log(`[Proxy] Đang chuyển tiếp xác thực thiết bị (${action}) tới: ${backendUrl}`);
    
    const response = await fetch(backendUrl);
    const htmlText = await response.text();

    return new NextResponse(htmlText, {
      status: response.status,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
      },
    });
  } catch (error) {
    console.error(`[Proxy] Lỗi khi chuyển tiếp xác thực thiết bị (${action}):`, error);
    return new NextResponse('<h1>Lỗi kết nối tới máy chủ xác thực của ngân hàng</h1>', {
      status: 500,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    });
  }
}
