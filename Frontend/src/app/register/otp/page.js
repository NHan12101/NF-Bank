'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getAccessToken } from '../../api';
import { RecaptchaVerifier, signInWithPhoneNumber } from 'firebase/auth';
import { auth } from '../../firebase';

export default function RegisterOTPPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [otpChannel, setOtpChannel] = useState('');
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [confirmationResult, setConfirmationResult] = useState(null);
  
  const inputsRef = useRef([]);
  const sendTriggeredRef = useRef(false);

  useEffect(() => {
    // Redirect if already logged in
    if (getAccessToken()) {
      router.push('/dashboard');
      return;
    }

    const savedEmail = sessionStorage.getItem('register_email');
    const savedPhone = sessionStorage.getItem('register_phone');
    const savedChannel = sessionStorage.getItem('register_otp_channel');

    if (!savedEmail) {
      router.push('/register');
      return;
    }

    setEmail(savedEmail);
    setPhone(savedPhone || '');
    setOtpChannel(savedChannel || 'email');

    // If OTP channel is SMS, trigger sending OTP
    if (savedChannel === 'sms' && savedPhone) {
      if (!sendTriggeredRef.current) {
        sendTriggeredRef.current = true;
        // Delay sending SMS OTP to allow reCAPTCHA container to be fully rendered in the DOM
        setTimeout(() => {
          sendSmsOtp(savedPhone);
        }, 800);
      }
    } else if (savedChannel === 'email') {
      setStatusMessage('Hệ thống đã gửi mã xác thực OTP vào hòm thư email của bạn.');
    }
  }, [router]);

  useEffect(() => {
    return () => {
      if (window.recaptchaVerifier) {
        try {
          window.recaptchaVerifier.clear();
        } catch (e) {}
        window.recaptchaVerifier = null;
      }
    };
  }, []);

  const setupRecaptcha = () => {
    if (window.recaptchaVerifier) {
      try {
        window.recaptchaVerifier.clear();
      } catch (e) {}
      window.recaptchaVerifier = null;
    }
    
    const container = document.getElementById('recaptcha-container');
    if (container) {
      container.innerHTML = '';
    }

    window.recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
      size: 'invisible',
      callback: () => {
        // reCAPTCHA solved
      },
      'expired-callback': () => {
        // reCAPTCHA expired
      }
    });
  };

  const formatPhoneForFirebase = (phoneNum) => {
    if (!phoneNum) return '';
    let cleaned = phoneNum.replace(/\D/g, '');
    if (cleaned.startsWith('0')) {
      return '+84' + cleaned.slice(1);
    }
    if (cleaned.startsWith('84')) {
      return '+' + cleaned;
    }
    return '+' + cleaned;
  };

  const sendSmsOtp = async (phoneNumber) => {
    setLoading(true);
    setError('');
    setStatusMessage('Đang gửi mã xác thực SMS qua Firebase...');
    try {
      setupRecaptcha();
      const appVerifier = window.recaptchaVerifier;
      const formattedPhone = formatPhoneForFirebase(phoneNumber);
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, appVerifier);
      setConfirmationResult(confirmation);
      setStatusMessage(`Mã SMS OTP đã được gửi đến số điện thoại ${maskPhone(phoneNumber)}.`);
    } catch (err) {
      console.error('Lỗi gửi SMS OTP:', err);
      setError('Không thể gửi mã SMS OTP. Chi tiết: ' + err.message);
      setStatusMessage('');
      sendTriggeredRef.current = false;
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = (e) => {
    e.preventDefault();
    if (loading) return;

    if (otpChannel === 'sms') {
      sendSmsOtp(phone);
    } else {
      // Re-trigger register to send email OTP again
      resendEmailOtp();
    }
  };

  const resendEmailOtp = async () => {
    setLoading(true);
    setError('');
    setStatusMessage('Đang gửi lại mã OTP email...');
    try {
      // We can resend by sending a dummy register call, or let them know it has been sent.
      // Since Backend register endpoint creates/updates pending records, we can call it again.
      // However, we don't have the password anymore in sessionStorage for security.
      // So let's alert user or fallback.
      setError('Vui lòng kiểm tra lại hộp thư hoặc đăng ký lại từ đầu nếu không nhận được email.');
      setStatusMessage('');
    } catch (err) {
      setError('Đã xảy ra lỗi khi gửi lại mã.');
    } finally {
      setLoading(false);
    }
  };

  const maskPhone = (phoneNumber) => {
    if (!phoneNumber) return '';
    if (phoneNumber.length < 4) return phoneNumber;
    return phoneNumber.slice(0, 3) + '******' + phoneNumber.slice(-3);
  };

  const handleOtpChange = (index, value) => {
    if (isNaN(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value;
    setOtp(newOtp);

    // Auto-focus next input
    if (value !== '' && index < 5) {
      inputsRef.current[index + 1].focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace' && otp[index] === '' && index > 0) {
      inputsRef.current[index - 1].focus();
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const otpCode = otp.join('');
    if (otpCode.length < 6) {
      setError('Vui lòng nhập đủ 6 chữ số OTP.');
      return;
    }

    setError('');
    setLoading(true);

    try {
      let payload = { email };

      if (otpChannel === 'sms' && confirmationResult) {
        // Verify SMS OTP on Firebase and get ID Token
        const credential = await confirmationResult.confirm(otpCode);
        const idToken = await credential.user.getIdToken();
        payload.id_token = idToken;
      } else {
        // Verify via Email OTP or direct OTP fallback if Firebase failed
        payload.otp = otpCode;
      }

      // Submit verification token/code to backend
      const res = await apiFetch('/auth/verify-register', {
        method: 'POST',
        body: JSON.stringify(payload),
      });

      const resData = await res.json();

      if (res.ok && resData.success) {
        setStatusMessage('Xác thực tài khoản thành công! Đang chuyển hướng về trang đăng nhập...');
        sessionStorage.removeItem('register_email');
        sessionStorage.removeItem('register_phone');
        sessionStorage.removeItem('register_otp_channel');
        
        setTimeout(() => {
          router.push('/login');
        }, 2000);
      } else {
        setError(resData.message || 'Mã xác thực không đúng hoặc đã hết hạn.');
      }
    } catch (err) {
      console.error("Xác minh OTP thất bại:", err);
      setError('Có lỗi xảy ra khi xác thực OTP. Vui lòng thử lại.');
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
      {/* Invisible container for Firebase reCAPTCHA */}
      <div id="recaptcha-container"></div>

      <div className="glass-container" id="reg-otp-container">
        <h1 id="reg-otp-title">Xác thực tài khoản</h1>
        <p className="subtitle" id="reg-otp-subtitle">
          {otpChannel === 'sms' ? (
            <>Hệ thống đã gửi một mã xác minh SMS đến số điện thoại <strong>{maskPhone(phone)}</strong>.</>
          ) : (
            <>Mã xác thực đăng ký đã được gửi đến email <strong>{email}</strong>. Vui lòng nhập mã để kích hoạt tài khoản.</>
          )}
        </p>

        {error && (
          <div className="alert alert-danger" id="reg-otp-error-alert" role="alert">
            {error}
          </div>
        )}

        {statusMessage && !error && (
          <div className="alert alert-info" id="reg-otp-status-alert" role="alert">
            {statusMessage}
          </div>
        )}

        <form onSubmit={handleSubmit} id="reg-otp-form">
          <div className="otp-container">
            {otp.map((digit, index) => (
              <input
                key={index}
                id={`reg-otp-digit-${index}`}
                ref={(el) => (inputsRef.current[index] = el)}
                type="text"
                maxLength="1"
                className="otp-input"
                value={digit}
                onChange={(e) => handleOtpChange(index, e.target.value)}
                onKeyDown={(e) => handleKeyDown(index, e)}
                disabled={loading}
                autoComplete="one-time-code"
                required
              />
            ))}
          </div>

          <button
            id="reg-otp-submit-btn"
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Đang xác thực...' : 'Xác thực'}
          </button>

          <button
            id="reg-otp-resend-btn"
            type="button"
            className="btn btn-secondary"
            style={{ marginTop: '12px' }}
            onClick={handleResendOtp}
            disabled={loading}
          >
            {otpChannel === 'sms' ? 'Gửi lại mã SMS OTP' : 'Hướng dẫn nhận lại mã'}
          </button>
        </form>
      </div>
    </div>
  );
}
