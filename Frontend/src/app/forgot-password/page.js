'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { getAccessToken, apiFetch } from '../api';

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // If logged in, redirect to dashboard
    if (getAccessToken()) {
      router.push('/dashboard');
    }
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    try {
      const res = await apiFetch('/auth/password-reset/request', {
        method: 'POST',
        body: JSON.stringify({ email: email.trim() }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        sessionStorage.setItem('reset_email', email.trim());
        setSuccess('Yêu cầu thành công! Nếu email tồn tại trên hệ thống, mã OTP đã được gửi.');
        
        setTimeout(() => {
          router.push('/reset-password');
        }, 2000);
      } else {
        setError(data.message || 'Yêu cầu thất bại. Vui lòng kiểm tra lại thông tin.');
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
      <div className="glass-container" id="forgot-password-container">
        <h1 id="forgot-password-title">Quên mật khẩu</h1>
        <p className="subtitle" id="forgot-password-subtitle">
          Nhập địa chỉ email của bạn để nhận mã OTP thiết lập lại mật khẩu
        </p>

        {error && (
          <div className="alert alert-danger" id="forgot-password-error" role="alert">
            {error}
          </div>
        )}

        {success && (
          <div className="alert alert-success" id="forgot-password-success" role="alert">
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} id="forgot-password-form">
          <div className="form-group">
            <label htmlFor="forgot-email-input">Địa chỉ Email</label>
            <input
              id="forgot-email-input"
              type="email"
              placeholder="ten@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              autoComplete="email"
            />
          </div>

          <button
            id="forgot-submit-btn"
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Đang xử lý...' : 'Gửi mã xác thực'}
          </button>
        </form>

        <div style={{ marginTop: '20px', textAlign: 'center', fontSize: '0.9rem' }} id="forgot-footer">
          <Link href="/login" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }} id="back-to-login">
            Quay lại đăng nhập
          </Link>
        </div>
      </div>
    </div>
  );
}
