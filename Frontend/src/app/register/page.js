'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { getAccessToken, apiFetch } from '../api';

export default function RegisterPage() {
  const router = useRouter();
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [otpChannel, setOtpChannel] = useState('email');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // If already logged in, redirect to dashboard
    if (getAccessToken()) {
      router.push('/dashboard');
    }
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    // Standardize phone: if starts with 0, convert to +84 for Vietnam standard
    let formattedPhone = phone.trim();
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+84' + formattedPhone.slice(1);
    }

    try {
      const res = await apiFetch('/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          email: email.trim(),
          full_name: fullName.trim(),
          phone: formattedPhone,
          password: password,
          otp_channel: otpChannel,
        }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        // Store registration info for verification screen
        sessionStorage.setItem('register_email', email.trim());
        sessionStorage.setItem('register_phone', formattedPhone);
        sessionStorage.setItem('register_otp_channel', otpChannel);

        setSuccess('Đăng ký bước đầu thành công! Đang chuyển đến trang xác thực OTP...');
        setTimeout(() => {
          router.push('/register/otp');
        }, 1500);
      } else {
        setError(data.message || 'Đăng ký thất bại. Vui lòng kiểm tra lại thông tin.');
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
      <div className="glass-container" id="register-container">
        <h1 id="register-title">Đăng ký tài khoản</h1>
        <p className="subtitle" id="register-subtitle">Bắt đầu trải nghiệm dịch vụ ngân hàng số NF-Bank</p>

        {error && (
          <div className="alert alert-danger" id="register-error-alert" role="alert">
            {error}
          </div>
        )}

        {success && (
          <div className="alert alert-success" id="register-success-alert" role="alert">
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} id="register-form">
          <div className="form-group">
            <label htmlFor="reg-fullname-input">Họ và tên</label>
            <input
              id="reg-fullname-input"
              type="text"
              placeholder="Nguyễn Văn A"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="reg-email-input">Địa chỉ Email</label>
            <input
              id="reg-email-input"
              type="email"
              placeholder="a@gmail.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              autoComplete="email"
            />
          </div>

          <div className="form-group">
            <label htmlFor="reg-phone-input">Số điện thoại</label>
            <input
              id="reg-phone-input"
              type="text"
              placeholder="0912345678 hoặc +84..."
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="reg-password-input">Mật khẩu</label>
            <input
              id="reg-password-input"
              type="password"
              placeholder="Tối thiểu 8 ký tự (1 chữ hoa, 1 ký tự đặc biệt)"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              autoComplete="new-password"
            />
          </div>

          <div className="form-group">
            <label htmlFor="reg-otpchannel-select">Kênh xác thực OTP</label>
            <select
              id="reg-otpchannel-select"
              value={otpChannel}
              onChange={(e) => setOtpChannel(e.target.value)}
              required
              disabled={loading}
              style={{
                width: '100%',
                padding: '14px 16px',
                background: 'rgba(0, 0, 0, 0.3)',
                border: '1px solid var(--glass-border)',
                borderRadius: '12px',
                color: 'var(--text-primary)',
                cursor: 'pointer'
              }}
            >
              <option value="email" style={{ background: '#0d0f1a', color: '#fff' }}>Nhận mã qua Email</option>
              <option value="sms" style={{ background: '#0d0f1a', color: '#fff' }}>Nhận mã qua SMS (Firebase)</option>
            </select>
          </div>

          <button
            id="register-submit-btn"
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Đang xử lý...' : 'Đăng ký tài khoản'}
          </button>
        </form>

        <div style={{ marginTop: '20px', textAlign: 'center', fontSize: '0.9rem' }} id="register-footer">
          <span style={{ color: 'var(--text-secondary)' }}>Đã có tài khoản? </span>
          <Link href="/login" style={{ color: 'var(--primary)', textDecoration: 'none', fontWeight: '600' }} id="back-to-login-link">
            Đăng nhập ngay
          </Link>
        </div>
      </div>
    </div>
  );
}
