'use client';

import { useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { getAccessToken, apiFetch, clearSession } from '../api';

// Thời gian chờ: 5 phút không tương tác (5 * 60 * 1000 ms)
const TIMEOUT_MS = 5 * 60 * 1000;
// Key dùng để chia sẻ hoạt động giữa các tab
const LAST_ACTIVE_KEY = 'nfbank_last_active';
const LOGGED_OUT_SIGNAL_KEY = 'nfbank_logged_out_signal';

export default function SessionTimeout() {
  const router = useRouter();
  const timerRef = useRef(null);

  useEffect(() => {
    // 1. Hàm thực hiện đăng xuất
    const performLogout = async (triggerApi = true) => {
      // Clear session local trước
      clearSession();

      if (triggerApi) {
        // Gửi tín hiệu đăng xuất tới các tab khác để cùng chuyển hướng
        localStorage.setItem(LOGGED_OUT_SIGNAL_KEY, Date.now().toString());

        try {
          // Gọi API logout để hủy token trong MySQL DB ở backend
          await apiFetch('/auth/logout', { method: 'POST' });
        } catch (err) {
          console.error('Lỗi khi gọi API logout:', err);
        }
      }

      // Hủy bỏ timer
      if (timerRef.current) clearTimeout(timerRef.current);

      // Chuyển hướng về trang login kèm lý do hết hạn
      router.push('/login?expired=1');
    };

    // 2. Hàm thiết lập hoặc làm mới bộ đếm ngược
    const resetTimer = () => {
      if (timerRef.current) clearTimeout(timerRef.current);

      // Nếu không có token (chưa đăng nhập), không cần đếm ngược
      if (!getAccessToken()) return;

      timerRef.current = setTimeout(() => {
        // Kiểm tra lại lần cuối xem có tab nào hoạt động gần đây không
        const lastActive = parseInt(localStorage.getItem(LAST_ACTIVE_KEY) || '0', 10);
        const now = Date.now();

        if (now - lastActive >= TIMEOUT_MS) {
          // Đã hết hạn thực sự trên mọi tab
          performLogout(true);
        } else {
          // Nếu có tab khác vừa hoạt động, thiết lập lại timer cho thời gian còn lại
          const remaining = TIMEOUT_MS - (now - lastActive);
          timerRef.current = setTimeout(() => performLogout(true), remaining);
        }
      }, TIMEOUT_MS);
    };

    // 3. Lắng nghe các tương tác của người dùng để cập nhật thời gian hoạt động
    const handleActivity = () => {
      if (!getAccessToken()) return;

      const now = Date.now();
      // Cập nhật hoạt động vào localStorage để các tab khác cùng biết
      localStorage.setItem(LAST_ACTIVE_KEY, now.toString());
      resetTimer();
    };

    // 4. Lắng nghe thay đổi localStorage để đồng bộ giữa các tab
    const handleStorageChange = (e) => {
      if (e.key === LAST_ACTIVE_KEY) {
        // Có tab khác vừa tương tác -> cập nhật lại timer ở tab này
        resetTimer();
      } else if (e.key === LOGGED_OUT_SIGNAL_KEY) {
        // Có tab khác vừa phát lệnh đăng xuất -> đăng xuất ngay không gọi API nữa
        performLogout(false);
      }
    };

    // Đăng ký lắng nghe sự kiện tương tác
    const events = ['mousemove', 'mousedown', 'keypress', 'scroll', 'touchstart'];
    events.forEach((event) => {
      window.addEventListener(event, handleActivity);
    });

    // Lắng nghe sự kiện storage từ các tab khác
    window.addEventListener('storage', handleStorageChange);

    // Lần đầu tiên khởi chạy: cập nhật hoạt động và kích hoạt timer
    if (getAccessToken()) {
      localStorage.setItem(LAST_ACTIVE_KEY, Date.now().toString());
      resetTimer();
    }

    // Dọn dẹp sự kiện khi component bị unmount
    return () => {
      events.forEach((event) => {
        window.removeEventListener(event, handleActivity);
      });
      window.removeEventListener('storage', handleStorageChange);
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [router]);

  return null; // Component chạy ngầm không hiển thị giao diện
}
