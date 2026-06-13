'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getAccessToken, clearSession } from '../api';
import Navbar from '../components/Navbar';

export default function ChangePasswordPage() {
  const router = useRouter();
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);

  useEffect(() => {
    const token = getAccessToken();
    if (!token) {
      router.push('/login');
    } else {
      setAuthenticated(true);
    }
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    if (newPassword.length < 8) {
      setError('Mật khẩu mới phải có ít nhất 8 ký tự.');
      setLoading(false);
      return;
    }

    const hasUppercase = /[A-Z]/.test(newPassword);
    const hasSpecial = /[!@#$%^&*(),.?":{}|<>]/.test(newPassword);

    if (!hasUppercase || !hasSpecial) {
      setError('Mật khẩu mới phải chứa ít nhất 1 chữ cái viết hoa và 1 ký tự đặc biệt.');
      setLoading(false);
      return;
    }

    if (oldPassword === newPassword) {
      setError('Mật khẩu mới không được trùng với mật khẩu cũ.');
      setLoading(false);
      return;
    }

    try {
      const res = await apiFetch('/auth/change-password', {
        method: 'PUT',
        body: JSON.stringify({
          old_password: oldPassword,
          new_password: newPassword,
        }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        setSuccess('Đổi mật khẩu thành công! Hệ thống đang đăng xuất...');
        setTimeout(() => {
          clearSession();
          router.push('/login');
        }, 2000);
      } else {
        setError(data.message || 'Thay đổi mật khẩu thất bại. Vui lòng kiểm tra lại mật khẩu cũ.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  if (!authenticated) {
    return (
      <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
        <div className="spinner pulse-animation" />
      </div>
    );
  }

  return (
    <>
      <Navbar />
      <div style={{
        display: 'flex',
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        padding: '40px 20px',
        minHeight: 'calc(100vh - 70px)'
      }}>
        <div className="glass-container" id="change-password-container">
          <h1 id="change-password-title">Đổi mật khẩu</h1>
          <p className="subtitle" id="change-password-subtitle">
            Cập nhật mật khẩu định kỳ để bảo vệ tài khoản ngân hàng của bạn
          </p>

          {error && (
            <div className="alert alert-danger" id="change-password-error" role="alert">
              {error}
            </div>
          )}

          {success && (
            <div className="alert alert-success" id="change-password-success" role="alert">
              {success}
            </div>
          )}

          <form onSubmit={handleSubmit} id="change-password-form">
            <div className="form-group">
              <label htmlFor="old-password-input">Mật khẩu hiện tại</label>
              <input
                id="old-password-input"
                type="password"
                placeholder="••••••••"
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                required
                disabled={loading}
              />
            </div>

            <div className="form-group">
              <label htmlFor="new-password-input">Mật khẩu mới</label>
              <input
                id="new-password-input"
                type="password"
                placeholder="Tối thiểu 8 ký tự (1 chữ hoa, 1 ký tự đặc biệt)"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                disabled={loading}
              />
            </div>

            <button
              id="change-password-submit-btn"
              type="submit"
              className="btn btn-primary"
              disabled={loading}
            >
              {loading ? 'Đang thực hiện...' : 'Cập nhật mật khẩu'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
