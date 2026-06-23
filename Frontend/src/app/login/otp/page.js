'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, setAccessToken, setUser, getAccessToken } from '../../api';
import { RecaptchaVerifier, signInWithPhoneNumber } from 'firebase/auth';
import { auth } from '../../firebase';

export default function OTPPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [pendingVerification, setPendingVerification] = useState(false);
  const [pendingID, setPendingID] = useState('');
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

    const savedEmail = sessionStorage.getItem('otp_email');
    const savedPhone = sessionStorage.getItem('otp_phone');
    if (!savedEmail) {
      router.push('/login');
      return;
    }

    setEmail(savedEmail);
    if (savedPhone) {
      setPhone(savedPhone);
      if (!sendTriggeredRef.current) {
        sendTriggeredRef.current = true;
        // Delay sending OTP to allow reCAPTCHA container to be fully rendered in the DOM
        setTimeout(() => {
          sendOtp(savedPhone);
        }, 800);
      }
    } else {
      setError('Không tìm thấy thông tin số điện thoại liên kết.');
    }
  }, [router]);

  // Handle Polling for device verification
  useEffect(() => {
    if (!pendingVerification || !pendingID) return;

    setStatusMessage('Đang chờ bạn xác thực qua email...');
    const interval = setInterval(async () => {
      try {
        const res = await fetch(`/api/v1/auth/login/status?pending_id=${pendingID}`);
        const data = await res.json();

        // Check raw status if status field is returned directly
        if (data.status) {
          if (data.status === 'PENDING') {
            return;
          }
          if (data.status === 'REJECTED') {
            setError('Đăng nhập bị từ chối. Tài khoản của bạn đã bị khóa khẩn cấp để đảm bảo an toàn.');
            setPendingVerification(false);
            clearInterval(interval);
            return;
          }
          if (data.status === 'EXPIRED') {
            setError('Yêu cầu xác thực đã hết hạn. Vui lòng đăng nhập lại.');
            setPendingVerification(false);
            clearInterval(interval);
            return;
          }
        }

        // If success: true is returned (APPROVED case)
        if (data.success && data.data) {
          const authData = data.data;
          setAccessToken(authData.access_token);
          setUser(authData.user);
          sessionStorage.removeItem('otp_email');
          sessionStorage.removeItem('otp_phone');
          clearInterval(interval);
          router.push('/dashboard');
        }
      } catch (err) {
        console.error('Polling error:', err);
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [pendingVerification, pendingID, router]);

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

  const sendOtp = async (phoneNumber) => {
    setLoading(true);
    setError('');
    setStatusMessage('Đang gửi mã xác thực SMS...');
    try {
      setupRecaptcha();
      const appVerifier = window.recaptchaVerifier;
      const formattedPhone = formatPhoneForFirebase(phoneNumber);
      console.log("👉 Số điện thoại gửi sang Firebase để nhận SMS:", formattedPhone);
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, appVerifier);
      setConfirmationResult(confirmation);
      setStatusMessage(`Mã OTP đã được gửi đến số điện thoại ${maskPhone(phoneNumber)}.`);
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
    // Bỏ qua clear recaptcha để tránh mất phần tử DOM, chỉ gửi lại OTP trực tiếp
    sendOtp(phone);
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
      let bodyData = { email };

      if (confirmationResult) {
        // 1. Xác thực OTP trên Firebase và lấy ID Token
        const credential = await confirmationResult.confirm(otpCode);
        const idToken = await credential.user.getIdToken();
        bodyData.id_token = idToken;
      } else {
        // Fallback: gửi trực tiếp mã OTP lên Backend (email OTP hoặc bypass SMS)
        bodyData.otp = otpCode;
      }

      // 2. Gửi ID Token hoặc OTP lên Backend để hoàn tất đăng nhập
      const res = await apiFetch('/auth/confirm-login', {
        method: 'POST',
        body: JSON.stringify(bodyData),
      });

      const resData = await res.json();

      if (res.ok && resData.success) {
        const authData = resData.data;
        if (authData.pending_verification) {
          // Device needs email confirmation
          setPendingVerification(true);
          setPendingID(authData.pending_id);
        } else {
          // Normal login success
          setAccessToken(authData.access_token);
          setUser(authData.user);
          sessionStorage.removeItem('otp_email');
          sessionStorage.removeItem('otp_phone');
          router.push('/dashboard');
        }
      } else {
        setError(resData.message || 'Mã xác thực không chính xác hoặc đã hết hạn.');
      }
    } catch (err) {
      console.error("Xác minh OTP thất bại:", err);
      setError('Mã OTP không đúng hoặc đã hết hạn. Vui lòng thử lại.');
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

      <div className="glass-container" id="otp-container">
        {!pendingVerification ? (
          <>
            <h1 id="otp-title">Xác thực OTP</h1>
            <p className="subtitle" id="otp-subtitle">
              Hệ thống đã gửi một mã xác minh SMS đến số điện thoại liên kết của tài khoản <strong>{email}</strong>. Vui lòng nhập mã để hoàn tất đăng nhập.
            </p>

            {error && (
              <div className="alert alert-danger" id="otp-error-alert" role="alert">
                {error}
              </div>
            )}

            {statusMessage && !error && (
              <div className="alert alert-info" id="otp-status-alert" role="alert">
                {statusMessage}
              </div>
            )}

            <form onSubmit={handleSubmit} id="otp-form">
              <div className="otp-container">
                {otp.map((digit, index) => (
                  <input
                    key={index}
                    id={`otp-digit-${index}`}
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
                id="otp-submit-btn"
                type="submit"
                className="btn btn-primary"
                disabled={loading}
              >
                {loading ? 'Đang xác thực...' : 'Xác thực'}
              </button>

              <button
                id="otp-resend-btn"
                type="button"
                className="btn btn-secondary"
                style={{ marginTop: '12px' }}
                onClick={handleResendOtp}
                disabled={loading}
              >
                Gửi lại mã OTP
              </button>
            </form>
          </>
        ) : (
          <div style={{ textAlign: 'center' }} id="device-pending-view">
            <h1 id="device-pending-title" style={{ background: 'linear-gradient(135deg, #ffffff 30%, #ef4444 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
              Phát hiện thiết bị lạ!
            </h1>
            <div className="spinner pulse-animation" style={{ borderColor: 'rgba(239, 68, 68, 0.1)', borderTopColor: 'var(--error)' }} id="device-pending-spinner" />
            
            <div className="alert alert-info" id="device-pending-instruction" style={{ textAlign: 'left', marginTop: '20px', lineHeight: '1.6' }}>
              <p style={{ fontWeight: 'bold', marginBottom: '8px' }}>Yêu cầu xác nhận thiết bị:</p>
              <p style={{ marginBottom: '12px' }}>
                Hệ thống nhận thấy bạn đang đăng nhập trên một thiết bị chưa từng được sử dụng trước đây. Chúng tôi đã gửi một email xác minh đến hộp thư của bạn.
              </p>
              <p style={{ marginBottom: '12px' }}>
                - Nếu đúng là bạn đang đăng nhập, vui lòng mở email và nhấn <strong>&quot;Có, đúng là tôi&quot;</strong> để cho phép thiết bị này.
              </p>
              <p>
                - Nếu bạn không thực hiện yêu cầu này, vui lòng nhấn <strong>&quot;Không, đó không phải tôi&quot;</strong> trong email để tạm thời <strong>khóa tài khoản ngay lập tức</strong> và bảo vệ tài sản của mình.
              </p>
            </div>

            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginTop: '16px' }} id="device-pending-status">
              {statusMessage}
            </p>

            <div style={{ marginTop: '24px', borderTop: '1px solid var(--glass-border)', paddingTop: '16px', fontSize: '0.85rem', color: 'var(--text-muted)' }} id="device-pending-hotline">
              Hotline hỗ trợ khẩn cấp: <strong>1900-XXXX</strong>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
