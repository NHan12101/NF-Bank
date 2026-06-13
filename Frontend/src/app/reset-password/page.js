'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { getAccessToken, apiFetch } from '../api';

export default function ResetPasswordPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // If logged in, redirect to dashboard
    if (getAccessToken()) {
      router.push('/dashboard');
      return;
    }

    const savedEmail = sessionStorage.getItem('reset_email');
    if (savedEmail) {
      setEmail(savedEmail);
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

    try {
      const res = await apiFetch('/auth/password-reset/confirm', {
        method: 'POST',
        body: JSON.stringify({
          email: email.trim(),
          otp: otp.trim(),
          new_password: newPassword,
        }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        setSuccess('Đặt lại mật khẩu thành công! Đang chuyển hướng về trang đăng nhập...');
        sessionStorage.removeItem('reset_email');
        
        setTimeout(() => {
          router.push('/login');
        }, 2000);
      } else {
        setError(data.message || 'Thiết lập mật khẩu thất bại. Vui lòng kiểm tra lại mã OTP.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      display: 'flex',
      flex: 1,
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      padding: '20px'
    }}>
      <div className="glass-container" id="reset-password-container">
        <h1 id="reset-password-title">Đặt lại mật khẩu</h1>
        <p className="subtitle" id="reset-password-subtitle">
          Nhập mã xác thực OTP và thiết lập mật khẩu mới của bạn
        </p>

        {error && (
          <div className="alert alert-danger" id="reset-password-error" role="alert">
            {error}
          </div>
        )}

        {success && (
          <div className="alert alert-success" id="reset-password-success" role="alert">
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} id="reset-password-form">
          <div className="form-group">
            <label htmlFor="reset-email-input">Địa chỉ Email</label>
            <input
              id="reset-email-input"
              type="email"
              placeholder="ten@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              autoComplete="email"
            />
          </div>

          <div className="form-group">
            <label htmlFor="reset-otp-input">Mã xác thực OTP</label>
            <input
              id="reset-otp-input"
              type="text"
              placeholder="6 chữ số OTP"
              maxLength="6"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              required
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="reset-newpassword-input">Mật khẩu mới</label>
            <input
              id="reset-newpassword-input"
              type="password"
              placeholder="Tối thiểu 8 ký tự (1 chữ hoa, 1 ký tự đặc biệt)"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              required
              disabled={loading}
              autoComplete="new-password"
            />
          </div>

          <button
            id="reset-submit-btn"
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Đang thực hiện...' : 'Đặt lại mật khẩu'}
          </button>
        </form>

        <div style={{ marginTop: '20px', textAlign: 'center', fontSize: '0.9rem' }} id="reset-footer">
          <Link href="/login" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }} id="reset-back-to-login">
            Quay lại đăng nhập
          </Link>
        </div>
      </div>
    </div>
  );
}
